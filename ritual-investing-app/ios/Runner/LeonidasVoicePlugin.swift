import AVFoundation
import Flutter

final class LeonidasVoicePlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
  private static let channelName = "ritual_investing/leonidas_voice"

  private var synthesizer: AVSpeechSynthesizer?
  private var activeUtterance: AVSpeechUtterance?
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = LeonidasVoicePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "speak":
      guard
        let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(false)
        return
      }

      cancelActiveSpeech()

      let utterance = AVSpeechUtterance(string: text)
      let requestedRate = (arguments["rate"] as? NSNumber)?.floatValue ?? 1
      let requestedPitch = (arguments["pitch"] as? NSNumber)?.floatValue ?? 1
      utterance.rate = min(
        AVSpeechUtteranceMaximumSpeechRate,
        max(
          AVSpeechUtteranceMinimumSpeechRate,
          AVSpeechUtteranceDefaultSpeechRate * requestedRate
        )
      )
      utterance.pitchMultiplier = min(2, max(0.5, requestedPitch))

      activeUtterance = utterance
      pendingResult = result
      speechSynthesizer().speak(utterance)

    case "stop":
      cancelActiveSpeech()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    guard utterance === activeUtterance else { return }
    finishActiveSpeech(success: true)
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    guard utterance === activeUtterance else { return }
    finishActiveSpeech(success: false)
  }

  private func speechSynthesizer() -> AVSpeechSynthesizer {
    if let synthesizer { return synthesizer }
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.delegate = self
    self.synthesizer = synthesizer
    return synthesizer
  }

  private func cancelActiveSpeech() {
    if synthesizer?.isSpeaking == true {
      synthesizer?.stopSpeaking(at: .immediate)
    }
    finishActiveSpeech(success: false)
  }

  private func finishActiveSpeech(success: Bool) {
    let result = pendingResult
    pendingResult = nil
    activeUtterance = nil
    result?(success)
  }
}
