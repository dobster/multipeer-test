//
//  ViewController.swift
//  multipeertest
//
//  Created by Stu Dobbie on 28/6/18.
//  Copyright © 2018 Quoll Designs. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, UITableViewDataSource, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate, UITextFieldDelegate, MCBrowserViewControllerDelegate {

    private let defaults = UserDefaults.standard
    private let kDisplayNameKey = "Display Name"
    private let kPeerIDKey = "Peer ID"
    
    private var peerID: MCPeerID {
        let displayName = UIDevice.current.name

        if displayName == defaults.string(forKey: kDisplayNameKey) {
            let data = defaults.data(forKey: kPeerIDKey)!
            let peerID = NSKeyedUnarchiver.unarchiveObject(with: data) as! MCPeerID
            return peerID
        } else {
            let peerID = MCPeerID(displayName: displayName)
            let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerID)
            defaults.set(displayName, forKey: kDisplayNameKey)
            defaults.set(peerIDData, forKey: kPeerIDKey)
            return peerID
        }
    }
    
    private let serviceType = "multipeer-test"

    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var textField: UITextField!
    
    private var messages: [String] = []
    private var advertiser: MCNearbyServiceAdvertiser?
    private var session: MCSession?
    private var peers: [MCPeerID] = []
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        tableView.dataSource = self
        
        session = MCSession(peer: peerID)
        session?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        updateTitle()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.disconnect()
    }
    
    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = messages[indexPath.row]
        return cell
    }
    
    // MARK: - Title
    
    func updateTitle() {
        if peers.count > 0 {
            self.title = "\(peers.count) friends"
        } else {
            self.title = "No friends yet"
        }
    }
    
    // MARK: - Button Actions
    
    @IBAction func didTapBrowse(_ sender: Any) {
        if let session = session {
            let browserController = MCBrowserViewController(serviceType: serviceType, session: session)
            browserController.delegate = self
            present(browserController, animated: true, completion: nil)
        }
    }
    
    @IBAction func didTapSend(_ sender: Any) {
        view.endEditing(true)
        if let message = textField.text, message.count > 0 {
            messages.append(message)
            tableView.reloadData()
            print("sending \(message)")
            if let data = message.data(using: .utf8) {
                try? session?.send(data, toPeers: peers, with: .reliable)
            }
        }
    }
    
    @IBAction func didTapClear(_ sender: Any) {
        messages = []
        tableView.reloadData()
    }
    
    // MARK: - MCNearbyServiceAdvertiserDelegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        present(alertController, animated: true, completion: nil)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    // MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = String(data: data, encoding: .utf8) {
            print("received \(message)")
            DispatchQueue.main.async {
                self.messages.append(message)
                self.tableView.reloadData()
            }
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            if !peers.contains(peerID) {
                peers.append(peerID)
            }
        case .notConnected:
            if let index = peers.index(of: peerID) {
                peers.remove(at: index)
            }
        case .connecting:
            print("Connecting \(peerID)...")
        }
        updateTitle()
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("session:didStartReceivingResourceWithName:\(resourceName) fromPeer:\(peerID) withProgress:\(progress.completedUnitCount)")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("session:didReceiveStream:withName:\(streamName) fromPeer:\(peerID)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("session:didFinishReceivingResourceWithName:\(resourceName) fromPeer:\(peerID) atLocalURL:\(localURL?.absoluteString ?? "") withError:\(error?.localizedDescription ?? "")")
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
    
    // MARK: - MCBrowserViewControllerDelegate
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

