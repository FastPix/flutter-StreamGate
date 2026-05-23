import ReplayKit

class BroadcastSetupViewController:
RPBroadcastActivityViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let url = URL(string: "https://streamgate.app")!

        extensionContext?.completeRequest(
            withBroadcast: url,
            setupInfo: [:]
        )
    }
}