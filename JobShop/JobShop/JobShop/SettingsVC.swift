//
//  SettingsVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/17/26.
//

import UIKit

class SettingsVC: UITableViewController {

    
    @IBOutlet weak var dropMenu: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let settingsAction = UIAction(title: "Settings") { action in
            print("Settings tapped")

        }
        
        let savedAction = UIAction(title: "Saved Jobs") { action in
            print("Saved Jobs tapped")

        }
        
        let swipeAction = UIAction(title: "Swipe on Jobs") { action in
            print("Swipe tapped")

        }
        
        let logoutAction = UIAction(title: "Log Out", attributes: .destructive) { action in
            print("Logout tapped")

        }
        
        let menu = UIMenu(title: "Menu", children: [savedAction, swipeAction, settingsAction, logoutAction])
        
        // 3. Attach the menu to your Storyboard Bar Button Item
        dropMenu.menu = menu
        
        // Optional: Ensures the menu appears on the very first tap
        // instead of requiring a long-press
        dropMenu.primaryAction = nil
    }

    

}
