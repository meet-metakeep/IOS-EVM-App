//
//  ContentView.swift
//  IOS-EVM-App
//
//  Created by Meet  on 27/08/25.
//

import SwiftUI
import MetaKeep
import Web3

struct ContentView: View {
    // Inject MetaKeep SDK from the App entry point
    let sdk: MetaKeep
    
    // State variables to store wallet information
    @State private var walletInfo: String = "No wallet info yet"
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var userEthAddress: String? = nil
    @State private var lastTxHash: String? = nil

    // Constants
    // TODO: Add your OWN RPC URL here. You can get it from Alchemy / Infura
    // Line 35: Update this RPC URL
    private let sepoliaRPCs: [URL] = [
        URL(string: "Your RPC URL here")!
    ]
    private let toAddress = "0x97706df14a769e28ec897dac5ba7bcfa5aa9c444"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("MetaKeep Wallet")
                    .font(.title)
                    .fontWeight(.bold)
                
                Button(action: getWallet) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wallet.pass")
                        }
                        Text(isLoading ? "Getting Wallet..." : "Get Wallet")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                
                if let addr = userEthAddress {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From (your ETH):\n\(addr)")
                            .font(.footnote)
                            .textSelection(.enabled)
                        Text("To:\n\(toAddress)")
                            .font(.footnote)
                            .textSelection(.enabled)
                        Text("Amount: 0.001 ETH (Sepolia)")
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: { Task { await signAndSendTransaction() } }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Sign and Send 0.001 Sepolia ETH")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                ScrollView {
                    Text(walletInfo)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 240)
                
                if let hash = lastTxHash, let url = URL(string: "https://sepolia.etherscan.io/tx/\(hash)") {
                    Link("View on Etherscan", destination: url)
                        .font(.body.bold())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Wallet")
        }
        .onOpenURL { url in
            MetaKeep.companion.resume(url: url.description)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Get Wallet
    private func getWallet() {
        isLoading = true
        walletInfo = "Fetching wallet..."
        
        sdk.getWallet(
            callback: Callback(
                onSuccess: { (result: JsonResponse) in
                    DispatchQueue.main.async {
                        isLoading = false
                        print("onSuccess")
                        print(result.description)
                        
                        if let status = result.data["status"] as? String,
                           let wallet = result.data["wallet"] as? [String: Any],
                           let ethAddress = wallet["ethAddress"] as? String {
                            
                            self.userEthAddress = ethAddress
                            print("ETH Wallet Address: \(ethAddress)")
                            
                            walletInfo = """
                            Status: \(status)
                            
                            ETH Wallet Address:\n\(ethAddress)
                            """
                        } else {
                            walletInfo = "Unexpected response format: \(result.description)"
                        }
                    }
                },
                onFailure: { (error: JsonResponse) in
                    DispatchQueue.main.async {
                        isLoading = false
                        print("onFailure")
                        print(error.description)
                        
                        showError = true
                        errorMessage = "Failed to get wallet: \(error.description)"
                        walletInfo = "Error occurred while fetching wallet"
                    }
                }
            )
        )
    }

    // MARK: - Sign and Send Transaction
    private func signAndSendTransaction() async {
        guard let from = userEthAddress else {
            showError = true
            errorMessage = "Get wallet first to know your address"
            return
        }
        
        await MainActor.run {
            self.walletInfo = "Preparing transaction...\nFetching nonce and fees from Sepolia network..."
        }
        
        do {
            let nonceHex = try await fetchNonceHex(address: from)
            let (maxFeeHex, priorityFeeHex) = try await fetchFeeSuggestions()
            let gasLimitHex = "0x5208" // 21000
            let chainIdHex = "0xaa36a7" // Sepolia 11155111
            let valueWei: UInt64 = 1_000_000_000_000_000 // 0.001 ETH
            let valueHex = "0x" + String(valueWei, radix: 16)
            
            await MainActor.run {
                self.walletInfo = """
                Transaction prepared (Sepolia):
                Nonce: \(nonceHex)
                Max Fee: \(maxFeeHex)
                Priority Fee: \(priorityFeeHex)
                Gas Limit: \(gasLimitHex)
                Chain ID: 11155111 (Sepolia)
                Value: \(valueHex) wei (0.001 ETH)
                
                Requesting signature from MetaKeep...
                """
            }
            
            let txnString = """
                  {
                    "type": 2,
                    "to": "\(self.toAddress)",
                    "value": "\(valueHex)",
                    "nonce": "\(nonceHex)",
                    "data": "0x",
                    "chainId": "\(chainIdHex)",
                    "gas": "\(gasLimitHex)",
                    "maxFeePerGas": "\(maxFeeHex)",
                    "maxPriorityFeePerGas": "\(priorityFeeHex)"
                  }
              """
            
            let reason = "Send 0.001 Sepolia ETH"
            
            sdk.signTransaction(
                transaction: try JsonRequest(jsonString: txnString),
                reason: reason,
                callback: Callback(
                    onSuccess: { (result: JsonResponse) in
                        DispatchQueue.main.async {
                            print("signTransaction onSuccess")
                            print(result.description)
                            
                            let signed = result.data["signedRawTransaction"] as? String
                            let txHash = result.data["transactionHash"] as? String
                            self.lastTxHash = txHash
                            self.walletInfo = """
                            ✅ Transaction signed successfully!
                            
                            Signed TX Hash: \(txHash ?? "<nil>")
                            Raw Transaction: \(signed?.prefix(120) ?? "<nil>")...
                            
                            Broadcasting to Sepolia network...
                            """
                            
                            guard let raw = signed else { return }
                            Task { await self.broadcast(rawTransaction: raw) }
                        }
                    },
                    onFailure: { (error: JsonResponse) in
                        DispatchQueue.main.async {
                            print("signTransaction onFailure")
                            print(error.description)
                            self.showError = true
                            self.errorMessage = "Failed to sign: \(error.description)"
                        }
                    }
                )
            )
        } catch {
            await MainActor.run {
                self.showError = true
                self.errorMessage = "Transaction preparation failed: \(error.localizedDescription)"
                self.walletInfo = "❌ Error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Broadcast Transaction
    private func broadcast(rawTransaction: String) async {
        do {
            let result = try await rpc(method: "eth_sendRawTransaction", params: [rawTransaction])
            if let hash = result as? String {
                await MainActor.run {
                    self.lastTxHash = hash
                    self.walletInfo += "\n\nBroadcasted Hash: \(hash)"
                }
            }
        } catch {
            await MainActor.run {
                self.showError = true
                self.errorMessage = "Broadcast failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - RPC Helpers
    private func fetchNonceHex(address: String) async throws -> String {
        let result = try await rpc(method: "eth_getTransactionCount", params: [address, "pending"])
        guard let nonceHex = result as? String else { throw NSError(domain: "rpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid nonce response"]) }
        return nonceHex
    }
    
    private func fetchFeeSuggestions() async throws -> (String, String) {
        let result = try await rpc(method: "eth_getBlockByNumber", params: ["latest", false])
        guard let block = result as? [String: Any], let baseFeeHex = block["baseFeePerGas"] as? String else {
            return ("0x77359400", "0x3b9aca00") // Default: 2 gwei max fee, 1 gwei priority
        }
        let baseFee = hexToUInt64(baseFeeHex) ?? 1_000_000_000
        let priority: UInt64 = 1_000_000_000
        let maxFee = min(baseFee &* 2 &+ priority, UInt64.max)
        return ("0x" + String(maxFee, radix: 16), "0x" + String(priority, radix: 16))
    }
    
    private func rpc(method: String, params: [Any]) async throws -> Any {
        let urls = sepoliaRPCs
        
        for (index, url) in urls.enumerated() {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 30.0
                
                let payload: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": method,
                    "params": params
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                print("Trying RPC endpoint \(index + 1): \(url.absoluteString)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let http = response as? HTTPURLResponse else {
                    throw NSError(domain: "rpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]) }
                
                print("RPC response status: \(http.statusCode)")
                
                if !(200..<300).contains(http.statusCode) {
                    throw NSError(domain: "rpc", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "Unknown error")"]) }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let error = json?["error"] as? [String: Any] {
                    let code = error["code"] as? Int ?? -1
                    let msg = error["message"] as? String ?? "Unknown RPC error"
                    throw NSError(domain: "rpc", code: code, userInfo: [NSLocalizedDescriptionKey: "RPC Error \(code): \(msg)"]) }
                
                guard let result = json?["result"] else {
                    throw NSError(domain: "rpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result in RPC response: \(String(data: data, encoding: .utf8) ?? "Unknown")"]) }
                
                print("RPC \(method) successful with endpoint \(index + 1)")
                return result
                
            } catch {
                print("RPC endpoint \(index + 1) failed: \(error.localizedDescription)")
                if index == urls.count - 1 { throw error }
                continue
            }
        }
        
        throw NSError(domain: "rpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "All RPC endpoints failed"]) }
    
    private func hexToUInt64(_ hex: String) -> UInt64? {
        let cleaned = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        return UInt64(cleaned, radix: 16)
    }
}

#Preview {
    ContentView(sdk: MetaKeep(appId: "YOUR_APP_ID_HERE", appContext: AppContext()))
}
