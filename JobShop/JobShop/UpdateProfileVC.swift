//
//  UpdateProfileVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class UpdateProfileVC: UIViewController {

    @IBOutlet weak var errorMessage: UILabel!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var birthdayField: UIDatePicker!
    @IBOutlet weak var emailField: UITextField!
    
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.errorMessage.text = ""
        birthdayField.datePickerMode = .date
        birthdayField.maximumDate = Date()
        emailField.text = Auth.auth().currentUser?.email
        loadProfile()
        // Do any additional setup after loading the view.
    }
    
    func loadProfile() {
        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).getDocument {
            (document,err) in
            if let err = err {
                self.errorMessage.text = "\(err.localizedDescription)"
            } else if let data = document?.data() {
                self.firstNameField.text = data["firstName"] as? String
                self.lastNameField.text = data["lastName"] as? String
                if let birthday = data["birthday"] as? Timestamp {
                    self.birthdayField.date = birthday.dateValue()
                }
            }
        }
        }
    
    @IBAction func logoutPressed(_ sender: Any) {
        do {
                try Auth.auth().signOut()
            } catch let signOutError as NSError {
                self.errorMessage.text = "\(signOutError.localizedDescription)"
                return
            }

            // go back to the first screen of the app, dropping every screen stacked on top of it
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let welcome = storyboard.instantiateInitialViewController() {
                view.window?.rootViewController = welcome
                view.window?.makeKeyAndVisible()
            }
    }
    @IBAction func savePressed(_ sender: Any) {
        self.errorMessage.text = ""
        
        // validate name and last name are present
        if firstNameField.text!.isEmpty || lastNameField.text!.isEmpty {
            self.errorMessage.text = "Please enter your first and last name."
            return
        }

        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).setData([
            "firstName": firstNameField.text!,
            "lastName": lastNameField.text!,
            "birthday": Timestamp(date: birthdayField.date)
        ], merge: true) { err in
            if let err = err {
                self.errorMessage.text = "\(err.localizedDescription)"
            } else {
                self.dismiss(animated: true)
            }
        }

    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }

}
