//
//  LogInVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import FirebaseAuth

class LogInVC: UIViewController {

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var errorMessage: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.emailField.text = ""
        self.passwordField.text = ""
        self.errorMessage.text = ""
    }
    
    @IBAction func loginDone(_ sender: Any) {
        self.errorMessage.text = ""

        // make sure email and password are valid/present
        let email = emailField.text!.trimmingCharacters(in: .whitespaces)
        
        if email.isEmpty {
            self.errorMessage.text = "Please enter your email."
            return
        }
        
        if passwordField.text!.isEmpty {
            self.errorMessage.text = "Please enter your password."
            return
        }

        // actually validate the login
        Auth.auth().signIn(withEmail: email, password: passwordField.text!) {
            (authResult,error) in
            if let error = error as NSError? {
                self.errorMessage.text = "\(error.localizedDescription)"
            } else {
                self.passwordField.text = ""
                //self.performSegue(withIdentifier: "LoginToSettingsIdentifier", sender: nil)
            }
        }
    }
}
