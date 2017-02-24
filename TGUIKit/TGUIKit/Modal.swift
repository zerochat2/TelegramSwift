//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
open class ModalViewController : ViewController {
    
    open var closable:Bool {
        return true
    }
    
    open var background:NSColor {
        return .blackTransparent
    }
    
    
    open var isFullScreen:Bool {
        return false
    }
    
    open var containerBackground: NSColor {
        return .white
    }
    
    open var dynamicSize:Bool {
        return false
    }
    
    open func measure(size:NSSize) {
        
    }

    open var modalInteractions:ModalInteractions? {
        return nil
    }
    
    open override var responderPriority: HandlerPriority {
        return .modal
    }
    
    open override func firstResponder() -> NSResponder? {
        return self.view
    }
    
    open func close() {
        modal?.close()
    }
    
    override open func loadView() {
        super.loadView()
        viewDidLoad()
    }
}

private class ModalBackground : Control {
    fileprivate override func scrollWheel(with event: NSEvent) {
        
    }
}

public class ModalInteractions {
    let accept:(()->Void)?
    let cancel:(()->Void)?
    let acceptTitle:String
    let cancelTitle:String?
    let drawBorder:Bool
    let height:CGFloat
    var enables:((Bool)->Void)? = nil
    public init(acceptTitle:String, accept:(()->Void)? = nil, cancelTitle:String? = nil, cancel:(()->Void)? = nil, drawBorder:Bool = false, height:CGFloat = 50)  {
        self.drawBorder = drawBorder
        self.accept = accept
        self.cancel = cancel
        self.acceptTitle = acceptTitle
        self.cancelTitle = cancelTitle
        self.height = height
    }
    
    public func updateEnables(_ enable:Bool) -> Void {
        if let enables = enables {
            enables(enable)
        }
    }
    
}

private class ModalInteractionsContainer : View {
    let acceptView:TitleButton
    let cancelView:TitleButton?
    let interactions:ModalInteractions
    let borderView:View?
    init(interactions:ModalInteractions, modal:Modal) {
        self.interactions = interactions
        acceptView = TitleButton()
        acceptView.style = ControlStyle(font:.medium(.text),foregroundColor:.blueUI)
        acceptView.set(text: interactions.acceptTitle, for: .Normal)
        acceptView.sizeToFit()
        if let cancelTitle = interactions.cancelTitle {
            cancelView = TitleButton()
            cancelView?.style = ControlStyle(font:.medium(.text),foregroundColor:.blueUI)
            cancelView?.set(text: cancelTitle, for: .Normal)
            cancelView?.sizeToFit()
            
        } else {
            cancelView = nil
        }
        
        if interactions.drawBorder {
            borderView = View()
            borderView?.backgroundColor = .border
        } else {
            borderView = nil
        }
        
       
        
        super.init()
        
        if let cancel = interactions.cancel {
            cancelView?.set(handler: { _ in
                cancel()
            }, for: .Click)
        } else {
            cancelView?.set(handler: { [weak modal] _ in
                modal?.close()
            }, for: .Click)
        }
        
        if let accept = interactions.accept {
            acceptView.set(handler: { _ in
                accept()
            }, for: .Click)
        } else {
            acceptView.set(handler: { [weak modal] _ in
                modal?.close()
            }, for: .Click)

        }
        
        addSubview(acceptView)
        if let cancelView = cancelView {
            addSubview(cancelView)
        }
        if let borderView = borderView {
            addSubview(borderView)
        }
        
        interactions.enables = { [weak self] enable in
            self?.acceptView.isEnabled = enable
            self?.acceptView.apply(state: .Normal)
        }

    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate override func layout() {
        super.layout()
        
        acceptView.centerY(x:frame.width - acceptView.frame.width - 30)
        if let cancelView = cancelView {
            cancelView.centerY(x:acceptView.frame.minX - cancelView.frame.width - 30)
        }
        borderView?.frame = NSMakeRect(0, 0, frame.width, .borderSize)
    }
    
    
}

private class ModalContainerView: View {
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

public class Modal: NSObject {
    
    private var background:ModalBackground
    private var controller:ModalViewController?
    private var container:ModalContainerView!
    private var window:Window
    private let disposable:MetaDisposable = MetaDisposable()
    private var interactionsView:ModalInteractionsContainer?
    public let interactions:ModalInteractions?
    public init(controller:ModalViewController, for window:Window) {
        self.controller = controller
        self.window = window
        background = ModalBackground()
        background.backgroundColor = controller.background
        background.layer?.disableActions()
        self.interactions = controller.modalInteractions
        super.init()

        if let interactions = interactions {
            interactionsView = ModalInteractionsContainer(interactions: interactions, modal:self)
            interactionsView?.frame = NSMakeRect(0, controller.bounds.height, controller.bounds.width, interactions.height)
        }
       
        if controller.isFullScreen {
            controller._frameRect = window.contentView!.bounds
        }
        
        container = ModalContainerView(frame: containerRect)
        container.layer?.cornerRadius = .cornerRadius
        container.backgroundColor = controller.containerBackground
        container.addSubview(controller.view)
        
        if let interactionsView = interactionsView {
            container.addSubview(interactionsView)
        }
        
        background.addSubview(container)
        
        window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .All)
        
        window.set(escape: {[weak self] () -> KeyHandlerResult in
            if self?.controller?.escapeKeyAction() == .rejected {
                self?.close()
            }
            return .invoked
        }, with: self, priority: .high)
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let controller = self?.controller {
                return controller.returnKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Return, priority: .high)
        
        background.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        if controller.dynamicSize {
            background.customHandler.size = { [weak self] (size) in
                self?.controller?.measure(size: size)
            }
        }
        
    }
    
    public func resize(with size:NSSize, animated:Bool = true) {
        
        let focus:NSRect
        if let interactions = controller?.modalInteractions {
            focus = background.focus(NSMakeSize(size.width, size.height + interactions.height))
            interactionsView?.change(pos: NSMakePoint(0, size.height), animated: animated)
        } else {
            focus = background.focus(size)
        }
        container.change(size: focus.size, animated: animated)
        container.change(pos: focus.origin, animated: animated)
        
        controller?.view.change(size: size, animated: animated)
    }
    
    private var containerRect:NSRect {
        if let controller = controller {
            var containerRect = controller.bounds
            if let interactions = controller.modalInteractions {
                containerRect.size.height += interactions.height
            }
            return containerRect
        }
       return NSZeroRect
    }
    
    public func close(_ callAcceptInteraction:Bool = false) ->Void {
        window.removeAllHandlers(for: self)
        controller?.viewWillDisappear(true)
        
        if callAcceptInteraction, let interactionsView = interactionsView {
            interactionsView.interactions.accept?()
        }
        
        background.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: {[weak self] (complete) in
            if let stongSelf = self {
                stongSelf.background.removeFromSuperview()
                stongSelf.controller?.viewDidDisappear(true)
                stongSelf.controller?.modal = nil
                stongSelf.controller = nil
            }
        })
       
    }
    
    deinit {
        disposable.dispose()
    }
    
    func show() -> Void {
        // if let view
        if let controller = controller {
            disposable.set((controller.ready.get() |> take(1)).start(next: {[weak self, weak controller] (ready) in
                if let strongSelf = self, let view = self?.window.contentView, let controller = controller {
                    strongSelf.controller?.viewWillAppear(true)
                    strongSelf.background.frame = view.bounds
                    strongSelf.background.background = controller.isFullScreen ? controller.containerBackground : .blackTransparent
                    if !controller.isFullScreen {
                        strongSelf.container.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.3)
                    } else {
                        strongSelf.container.layer?.animateAlpha(from: 0.1, to: 1.0, duration: 0.3)
                        
                    }
                    strongSelf.background.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, completion:{[weak strongSelf] (completed) in
                        strongSelf?.controller?.viewDidAppear(true)
                    })
                    strongSelf.background.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
                    strongSelf.background.customHandler.layout = { [weak strongSelf] view in
                        strongSelf?.container.center()
                    }
                    view.addSubview(strongSelf.background)
                    
                }
            }))
        }
        
    }
    
}

public func showModal(with controller:ModalViewController, for window:Window) -> Void {
    assert(controller.modal == nil)
    
    controller.modal = Modal(controller: controller, for: window)
    controller.modal?.show()
}


