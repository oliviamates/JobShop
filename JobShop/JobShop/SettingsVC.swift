//
//  SettingsVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import UserNotifications


var globalNotifChoice: Double = 86400
var globalCal: Bool = false

class SettingsVC: UITableViewController, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var workingLocationsLabel: UILabel!
    
    @IBOutlet weak var dayButton: UIButton!
    
    
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        if let menuButton {
            menuButton.menu = makeNavMenu()              // storyboard button
        } else {
            navigationItem.rightBarButtonItem = makeMenuBarButtonItem()   // created in code
        }
        self.navigationItem.setHidesBackButton(true, animated: true)
        
        let optionOne = UIAction(title: "1 day after saving", handler: { action in
            self.selectDay(action.title)
        })

        let optionTwo = UIAction(title: "3 days after saving", handler: { action in
            self.selectDay(action.title)
        })

        let optionThree = UIAction(title: "7 days after saving", handler: { action in
            self.selectDay(action.title)
        })

        let dayMenu = UIMenu(children: [optionOne, optionTwo, optionThree])
        
        dayButton.menu = dayMenu
        dayButton.showsMenuAsPrimaryAction = true
        dayButton.changesSelectionAsPrimaryAction = true

    }
    


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        loadProfile()
        loadWorkingLocations()
    }
    
    @IBAction func requestPerm(_ sender: Any) {
        UNUserNotificationCenter.current().delegate = self
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                print("calendar Permission granted: \(granted)")
            
        }
 
    }
    
    func loadProfile() {
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("accounts").document(user.uid).getDocument { [weak self] (document, err) in
            guard let self = self else { return }
            
            if let err = err {
                print("Error loading profile: \(err.localizedDescription)")
            } else if let data = document?.data() {
                let first = data["firstName"] as? String ?? ""
                let last = data["lastName"] as? String ?? ""
                let email = data["email"] as? String ?? ""
                self.nameLabel?.text = "\(first) \(last)"
                self.emailLabel?.text = "\(email)"
            }
        }
    }
    
    
    @IBAction func remindersOn(_ sender: UISwitch) {
        if sender.isOn{
                globalCal = true
            } 
        
    }
    
    func loadWorkingLocations() {
        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).getDocument { [weak self] (document, err) in
            guard let self = self else { return }

            if let err = err {
                print("\(err.localizedDescription)")
            } else if let data = document?.data() {
                let locations = data["workingLocations"] as? [String] ?? []

                if locations.isEmpty {
                    self.workingLocationsLabel?.text = "No locations added"
                } else if locations.count <= 2 {
                    self.workingLocationsLabel?.text = locations.joined(separator: " · ")
                } else {
                    let firstTwo = locations.prefix(2).joined(separator: " · ")
                    let remaining = locations.count - 2
                    self.workingLocationsLabel?.text = "\(firstTwo) + \(remaining) more..."
                }
            }
        }
    }
    
    @IBOutlet weak var dayMenu: UIMenu!
    
    func selectDay(_ title: String){
        if title == "1 day after saving" {
            globalNotifChoice = 1 * 86400
        }
        else if title == "3 days after saving"{
            globalNotifChoice = 3 * 86400
        }
        else {
            globalNotifChoice = 7 * 86400
        }
        print(globalNotifChoice)
    }
    
    
    
    
    
}
