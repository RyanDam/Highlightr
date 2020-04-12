//
//  JSEngine.swift
//  Highlightr
//
//  Created by Bruno Philipe on 05.04.20.
//

import Foundation
import JavaScriptCore
import WebKit

protocol JSEngine {

	func evaluate(command: String) -> String?
}

extension JSContext: JSEngine {

	func evaluate(command: String) -> String? {
		return evaluateScript(command)!.toString()
	}
}

extension WKWebView: JSEngine {

	func evaluate(command: String) -> String? {

		let semaphore = DispatchSemaphore(value: 0)
		var returnValue: String? = nil

		evaluateJavaScript(command) { (result, error) in
			if error == nil, let string = result as? String {
				returnValue = string
			}
			semaphore.signal()
		}

		semaphore.wait()

		return returnValue
	}
}
