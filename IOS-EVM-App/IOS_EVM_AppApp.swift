//
//  IOS_EVM_AppApp.swift
//  IOS-EVM-App
//
//  Created by Meet  on 27/08/25.
//

import SwiftUI
import MetaKeep

@main
struct IOS_EVM_AppApp: App {
    // Init SDK
    // TODO: Replace with your own App ID from console.metakeep.xyz
    let sdk = MetaKeep(appId: "Your EVM app ID here", appContext: AppContext())

    var body: some Scene {
        WindowGroup {
            ContentView(sdk: sdk)
        }
    }
}
