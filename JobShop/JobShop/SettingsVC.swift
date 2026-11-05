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
    @IBOutlet weak var industriesLabel: UILabel!
    @IBOutlet weak var jobTypeLabel: UILabel!
    @IBOutlet weak var skillsLabel: UILabel!
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
        loadIndustries()
        loadJobTypes()
        loadSkills()
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
                } else if locations.count == 1 {
                    self.workingLocationsLabel?.text = locations[0]
                } else {
                    let remaining = locations.count - 1
                    self.workingLocationsLabel?.text = "\(locations[0]) + \(remaining) more"
                }
            }
        }
    }
    
    func loadIndustries() {
        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).getDocument { [weak self] (document, err) in
            guard let self = self else { return }

            if let err = err {
                print("\(err.localizedDescription)")
            } else if let data = document?.data() {
                let industries = data["industries"] as? [String] ?? []

                if industries.isEmpty {
                    self.industriesLabel?.text = "No industries added"
                } else if industries.count == 1 {
                    self.industriesLabel?.text = industries[0]
                } else {
                    let remaining = industries.count - 1
                    self.industriesLabel?.text = "\(industries[0]) + \(remaining) more"
                }
            }
        }
    }
    
    func loadJobTypes() {
        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).getDocument { [weak self] (document, err) in
            guard let self = self else { return }

            if let err = err {
                print("\(err.localizedDescription)")
            } else if let data = document?.data() {
                let jobTypes = data["jobTypes"] as? [String] ?? []
                
                if jobTypes.isEmpty {
                    self.jobTypeLabel?.text = "No job types added"
                } else if jobTypes.count == 1 {
                    self.jobTypeLabel?.text = jobTypes[0]
                } else {
                    let remaining = jobTypes.count - 1
                    self.jobTypeLabel?.text = "\(jobTypes[0]) + \(remaining) more"
                }
            }
        }
    }
    
    func loadSkills() {
        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).getDocument { [weak self] (document, err) in
            guard let self = self else { return }

            if let err = err {
                print("\(err.localizedDescription)")
            } else if let data = document?.data() {
                let skills = data["skills"] as? [String] ?? []
                
                if skills.isEmpty {
                    self.skillsLabel?.text = "No skills added"
                } else if skills.count == 1 {
                    self.skillsLabel?.text = skills[0]
                } else {
                    let remaining = skills.count - 1
                    self.skillsLabel?.text = "\(skills[0]) + \(remaining) more"
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
