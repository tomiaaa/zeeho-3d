import SwiftUI
import WebKit

struct WebAuthView: UIViewRepresentable {
    typealias TokenHandler = (String) async -> Bool
    let onToken: TokenHandler
    private let url = URL(string: "https://lswlc33.github.io/zeeho-3d-models/")!

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "zeehoAuth")
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
          const openPhoneLogin = () => {
            clickByText('账号设置');
            setTimeout(() => clickByText('手机号登录'), 450);
          };
          setTimeout(openPhoneLogin, 500);
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
        private var delivered = false
        init(onToken: @escaping WebAuthView.TokenHandler) { self.onToken = onToken }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "zeehoAuth", message.frameInfo.securityOrigin.host == "lswlc33.github.io", let value = message.body as? String, !value.isEmpty, !delivered else { return }
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
