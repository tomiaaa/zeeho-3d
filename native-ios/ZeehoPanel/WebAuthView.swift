import SwiftUI
import WebKit

struct WebAuthView: UIViewRepresentable {
    typealias TokenHandler = (String) async -> Bool
    typealias CodeSentHandler = () -> Void
    let phone: String
    let onToken: TokenHandler
    let onCodeSent: CodeSentHandler
    private let url = URL(string: "https://lswlc33.github.io/zeeho-3d-models/")!

    init(phone: String, onToken: @escaping TokenHandler = { _ in false }, onCodeSent: @escaping CodeSentHandler = {}) {
        self.phone = phone
        self.onToken = onToken
        self.onCodeSent = onCodeSent
    }

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken, onCodeSent: onCodeSent) }
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "zeehoAuth")
        controller.add(context.coordinator, name: "zeehoCodeSent")
        let phoneJSON = (try? JSONEncoder().encode(phone)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        let script = WKUserScript(source: """
        (() => {
          // The web panel keeps phone-login inside the account settings dialog.
          // Open that dialog for the native login flow so users see the same UI
          // as the browser instead of landing on the demo dashboard first.
          const clickByText = (text) => {
            const nodes = Array.from(document.querySelectorAll('button,[role="button"],[aria-label]'));
            const node = nodes.find((item) => ((item.getAttribute('aria-label') || '') + ' ' + (item.textContent || '')).includes(text));
            if (node) { node.click(); return true; }
            return false;
          };
          const phone = \(phoneJSON);
          const fillPhone = () => {
            const input = document.querySelector('#phoneInput,input[type="tel"],input[inputmode="numeric"]');
            if (!input || !phone) return;
            const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
            setter?.call(input, phone);
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
          };
          const watchCodeSent = () => {
            const buttons = Array.from(document.querySelectorAll('[data-act="sendcode"],button'));
            const button = buttons.find((item) => /秒|重新发送|已发送/.test(item.textContent || ''));
            if (button && !window.__zeehoCodeSent) {
              window.__zeehoCodeSent = true;
              window.webkit.messageHandlers.zeehoCodeSent.postMessage('sent');
            }
          };
          const openPhoneLogin = () => {
            clickByText('账号设置');
            setTimeout(() => { clickByText('手机号登录'); setTimeout(fillPhone, 450); }, 450);
          };
          setTimeout(openPhoneLogin, 500);
          setInterval(() => { fillPhone(); watchCodeSent(); }, 500);
          let initial = (() => { try { return localStorage.getItem('zeeho.token') || ''; } catch (_) { return ''; } })();
          let state = { last: initial, sentInitial: false };
          const send = () => {
            try {
              const token = (localStorage.getItem('zeeho.token') || '').trim();
              if (token && (token !== state.last || !state.sentInitial)) { state.last = token; state.sentInitial = true; window.webkit.messageHandlers.zeehoAuth.postMessage(token); }
            } catch (_) {}
          };
          setInterval(send, 500);
          send();
        })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)
        let configuration = WKWebViewConfiguration(); configuration.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onToken: TokenHandler
        let onCodeSent: CodeSentHandler
        private var delivered = false
        init(onToken: @escaping WebAuthView.TokenHandler, onCodeSent: @escaping WebAuthView.CodeSentHandler) { self.onToken = onToken; self.onCodeSent = onCodeSent }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.securityOrigin.host == "lswlc33.github.io" else { return }
            if message.name == "zeehoCodeSent" { Task { @MainActor in onCodeSent() }; return }
            guard message.name == "zeehoAuth", let value = message.body as? String, !value.isEmpty, !delivered else { return }
            delivered = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                let accepted = await onToken(value)
                if !accepted { delivered = false }
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.targetFrame?.isMainFrame != true || navigationAction.request.url?.host == "lswlc33.github.io" else { decisionHandler(.cancel); return }
            decisionHandler(.allow)
        }
    }
}
