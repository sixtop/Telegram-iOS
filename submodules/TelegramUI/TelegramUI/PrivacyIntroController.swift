import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

enum PrivacyIntroControllerMode {
    case passcode
    case twoStepVerification
    
    func icon(theme: PresentationTheme) -> UIImage? {
        switch self {
            case .passcode:
                return generateTintedImage(image: UIImage(bundleImageName: "Settings/PasscodeIntroIcon"), color: theme.list.freeTextColor)
            case .twoStepVerification:
                return generateTintedImage(image: UIImage(bundleImageName: "Settings/PasswordIntroIcon"), color: theme.list.freeTextColor)
        }
    }
    
    func controllerTitle(strings: PresentationStrings) -> String {
        switch self {
            case .passcode:
                return strings.PasscodeSettings_Title
            case .twoStepVerification:
                return strings.PrivacySettings_TwoStepAuth
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        switch self {
            case .passcode:
                return strings.PasscodeSettings_Title
            case .twoStepVerification:
                return strings.TwoStepAuth_AdditionalPassword
        }
    }
    
    func text(strings: PresentationStrings) -> String {
        switch self {
            case .passcode:
                return strings.PasscodeSettings_HelpTop
            case .twoStepVerification:
                return strings.TwoStepAuth_SetPasswordHelp
        }
    }
    
    func buttonTitle(strings: PresentationStrings) -> String {
        switch self {
        case .passcode:
            return strings.PasscodeSettings_TurnPasscodeOn
        case .twoStepVerification:
            return strings.TwoStepAuth_SetPassword
        }
    }
    
    func notice(strings: PresentationStrings) -> String {
        switch self {
            case .passcode:
                return strings.PasscodeSettings_HelpBottom
            case .twoStepVerification:
                return ""
        }
    }
}

final public class PrivacyIntroControllerPresentationArguments {
    let fadeIn: Bool
    let animateIn: Bool
    
    public init(fadeIn: Bool = false, animateIn: Bool = false) {
        self.fadeIn = fadeIn
        self.animateIn = animateIn
    }
}

final class PrivacyIntroController: ViewController {
    private let context: AccountContext
    private let mode: PrivacyIntroControllerMode
    private let arguments: PrivacyIntroControllerPresentationArguments
    private let proceedAction: () -> Void
    
    private var controllerNode: PrivacyIntroControllerNode {
        return self.displayNode as! PrivacyIntroControllerNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var isDismissed: Bool = false
    
    init(context: AccountContext, mode: PrivacyIntroControllerMode, arguments: PrivacyIntroControllerPresentationArguments = PrivacyIntroControllerPresentationArguments(), proceedAction: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.arguments = arguments
        self.proceedAction = proceedAction
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.mode.controllerTitle(strings: self.presentationData.strings)
        
        if arguments.animateIn {
            self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PrivacyIntroControllerNode(context: self.context, mode: self.mode, proceedAction: self.proceedAction)
        self.displayNodeDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.arguments.animateIn {
            self.controllerNode.animateIn(slide: true)
        } else if self.arguments.fadeIn {
            self.controllerNode.animateIn(slide: false)
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            if self.arguments.animateIn {
                self.controllerNode.animateOut(completion: { [weak self] in
                    self?.presentingViewController?.dismiss(animated: false, completion: nil)
                    completion?()
                })
            } else {
                self.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
