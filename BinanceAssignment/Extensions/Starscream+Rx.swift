//
//  Starscream+Rx.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/4.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import RxSwift
import RxCocoa
import Starscream

class WebSocketDelegateProxy: DelegateProxy<WebSocket, WebSocketDelegate>, DelegateProxyType, WebSocketDelegate {
    
    fileprivate let messageSubject = PublishSubject<String>()
    fileprivate let dataSubject = PublishSubject<Data>()
    fileprivate let disconnectSubject = PublishSubject<Error?>()
    
    static func registerKnownImplementations() {
        self.register { WebSocketDelegateProxy(parentObject: $0, delegateProxy: WebSocketDelegateProxy.self) }
    }
    
    static func currentDelegate(for object: WebSocket) -> WebSocketDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: WebSocketDelegate?, to object: WebSocket) {
        object.delegate = delegate
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        //
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        disconnectSubject.onNext(error)
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        messageSubject.onNext(text)
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        dataSubject.onNext(data)
    }
    
}


extension Reactive where Base: WebSocket {
    
    private var delegate: WebSocketDelegateProxy {
        return WebSocketDelegateProxy.proxy(for: base)
    }
    
    var didReceiveMessage: Observable<String> {
        return Observable.deferred({ self.delegate.messageSubject.asObservable() })
    }
    
    var didReceiveData: Observable<Data> {
        return Observable.deferred({ self.delegate.dataSubject.asObservable() })
    }
    
    var isDisconnected: Observable<Error?> {
        return Observable.deferred({ self.delegate.disconnectSubject.asObservable() })
    }
    
}
