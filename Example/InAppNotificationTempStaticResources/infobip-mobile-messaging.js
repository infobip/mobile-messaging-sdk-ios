window.InfobipMobileMessaging = (function () {
  const messages = {
    DOCUMENT_WAS_LOADED: 'documentWasLoaded',
    HEIGHT_CHANGED: 'heightChanged',
    CLOSE: 'close'
  }

  // API for the mobile SDK.
  const mobileSdkApi = Object.freeze({ registerMessageSendingOnDocumentLoad, readBodyHeight })

  // API to for the web page.
  const webPageApi = Object.freeze({ registerCloseOnClick })

  return Object.freeze({ mobileSdkApi, webPageApi })

  // PUBLIC

  /**
   * Ensures that once document becomes fully loaded, appropriate message will be sent to the web view. If document is
   * already fully loaded, the message will be sent immediately.
   * @returns {DocumentReadyState} - The current value of document's `readyState`.
   */
  function registerMessageSendingOnDocumentLoad () {
    if (document.readyState === 'complete') {
      sendMessageToWebView(messages.DOCUMENT_WAS_LOADED)
    } else {
      window.onload = function () { sendMessageToWebView(messages.DOCUMENT_WAS_LOADED) }
    }
    return document.readyState
  }

  function readBodyHeight() {
      return document.body.scrollHeight
  }

  function registerCloseOnClick (element, payload) {
    element.addEventListener('click', function () {
      sendMessageToWebView(messages.CLOSE, payload)
    })
  }

  // PRIVATE

  /** Sends the message with payload to the webView's message handler. */
  function sendMessageToWebView (messageName, payload) {
    window.webkit.messageHandlers[messageName].postMessage(payload)
  }
})()

