import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData

private final class ConvertToSupergroupArguments {
    let convert: () -> Void
    
    init(convert: @escaping () -> Void) {
        self.convert = convert
    }
}

private enum ConvertToSupergroupSection: Int32 {
    case info
    case action
}

private enum ConvertToSupergroupEntry: ItemListNodeEntry {
    case info(PresentationTheme, String)
    case action(PresentationTheme, String)
    case actionInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ConvertToSupergroupSection.info.rawValue
            case .action, .actionInfo:
                return ConvertToSupergroupSection.action.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .info:
                return 0
            case .action:
                return 1
            case .actionInfo:
                return 2
        }
    }
    
    static func ==(lhs: ConvertToSupergroupEntry, rhs: ConvertToSupergroupEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsText):
                if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .action(lhsTheme, lhsText):
                if case let .action(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .actionInfo(lhsTheme, lhsText):
                if case let .actionInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ConvertToSupergroupEntry, rhs: ConvertToSupergroupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ConvertToSupergroupArguments) -> ListViewItem {
        switch self {
            case let .info(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
            case let .action(theme, title):
                return ItemListActionItem(theme: theme, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.convert()
                })
            case let .actionInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        }
    }
}

private struct ConvertToSupergroupState: Equatable {
    let isConverting: Bool
    
    init() {
        self.isConverting = false
    }
    
    init(isConverting: Bool) {
        self.isConverting = isConverting
    }
    
    static func ==(lhs: ConvertToSupergroupState, rhs: ConvertToSupergroupState) -> Bool {
        if lhs.isConverting != rhs.isConverting {
            return false
        }
        return true
    }
}

private func convertToSupergroupEntries(presentationData: PresentationData) -> [ConvertToSupergroupEntry] {
    var entries: [ConvertToSupergroupEntry] = []
    
    entries.append(.info(presentationData.theme, "\(presentationData.strings.ConvertToSupergroup_HelpTitle)\n\(presentationData.strings.ConvertToSupergroup_HelpText)"))
    entries.append(.action(presentationData.theme, presentationData.strings.GroupInfo_ConvertToSupergroup))
    entries.append(.actionInfo(presentationData.theme, presentationData.strings.ConvertToSupergroup_Note))
    
    return entries
}

public func convertToSupergroupController(context: AccountContext, peerId: PeerId) -> ViewController {
    var replaceControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let statePromise = ValuePromise(ConvertToSupergroupState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ConvertToSupergroupState())
    let updateState: ((ConvertToSupergroupState) -> ConvertToSupergroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let convertDisposable = MetaDisposable()
    actionsDisposable.add(convertDisposable)
    
    let arguments = ConvertToSupergroupArguments(convert: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Group_UpgradeConfirmation, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
            var alreadyConverting = false
            updateState { state in
                if state.isConverting {
                    alreadyConverting = true
                }
                return ConvertToSupergroupState(isConverting: true)
            }
            
            if !alreadyConverting {
                convertDisposable.set((convertGroupToSupergroup(account: context.account, peerId: peerId)
                |> deliverOnMainQueue).start(next: { createdPeerId in
                    replaceControllerImpl?(ChatController(context: context, chatLocation: .peer(createdPeerId)))
                }))
            }
        })]), nil)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<ConvertToSupergroupEntry>, ConvertToSupergroupEntry.ItemGenerationArguments)) in
            
            var rightNavigationButton: ItemListNavigationButton?
            if state.isConverting {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.ConvertToSupergroup_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: convertToSupergroupEntries(presentationData: presentationData), style: .blocks)
            
            return (controllerState, (listState, arguments))
        }
        |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(context: context, state: signal)
    replaceControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.replaceAllButRootController(c, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    return controller
}
