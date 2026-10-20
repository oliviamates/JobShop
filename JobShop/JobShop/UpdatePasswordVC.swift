//
//  UpdatePasswordVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import FirebaseAuth

class UpdatePasswordVC: UIViewController {

    @IBOutlet weak var oldPasswordField: UITextField!
    @IBOutlet weak var newPasswordField: UITextField!
    @IBOutlet weak var errorMessage: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.oldPasswordField.text = ""
        self.newPasswordField.text = ""
        self.errorMessage.text = ""
    }
    

    @IBAction func savePressed(_ sender: Any) {
        self.errorMessage.text = ""

        // make sure both fields are present and valid
        if oldPasswordField.text!.isEmpty {
            self.errorMessage.text = "Please enter your current password."
            return
        }

        if newPasswordField.text!.isEmpty {
            self.errorMessage.text = "Please enter a new password."
            return
        }

        if newPasswordField.text!.count < 6 {
            self.errorMessage.text = "Your new password needs at least 6 characters."
            return
        }

        if newPasswordField.text! == oldPasswordField.text! {
            self.errorMessage.text = "Your new password must be different from your current one."
            return
        }

        guard let user = Auth.auth().currentUser, let email = user.email else { return }

        // first prove the old password is right
        let credential = EmailAuthProvider.credential(withEmail: email,
                                                      password: oldPasswordField.text!)

        user.reauthenticate(with: credential) { (authResult,error) in
            if let error = error as NSError? {
                self.errorMessage.text = "Error changing password. Make sure your original password is correct."
            } else {
                // then change it
                user.updatePassword(to: self.newPasswordField.text!) { error in
                    if let error = error as NSError? {
                        self.errorMessage.text = "\(error.localizedDescription)"
                    } else {
                        self.dismiss(animated: true)
                    }
                }
            }
        }
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
