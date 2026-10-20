import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateAccountVC: UIViewController {

    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var birthdayField: UIDatePicker!
    @IBOutlet weak var errorMessage: UILabel!
        
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.firstNameField.text = ""
        self.lastNameField.text = ""
        self.emailField.text = ""
        self.passwordField.text = ""
        birthdayField.datePickerMode = .date
        birthdayField.maximumDate = Date()
        self.errorMessage.text = ""
    }

    @IBAction func step1Done(_ sender: Any) {
        self.errorMessage.text = ""
        
        // make sure all the entered info is present/valid
        if firstNameField.text!.isEmpty || lastNameField.text!.isEmpty {
            self.errorMessage.text = "Please enter your first and last name."
            return
        }
        
        let email = emailField.text!.trimmingCharacters(in: .whitespaces)

        if email.isEmpty {
            self.errorMessage.text = "Please enter your email."
            return
        }

        if passwordField.text!.isEmpty {
            self.errorMessage.text = "Please enter a password."
            return
        }

        if passwordField.text!.count < 6 {
            self.errorMessage.text = "Password must be at least 6 characters."
            return
        }

        // handle actually making the account
        Auth.auth().createUser(withEmail: email, password: passwordField.text!) {
            (authResult,error) in
            if let error = error as NSError? {
                self.errorMessage.text = "\(error.localizedDescription)"
            } else {
                let user = authResult!.user

                self.db.collection("accounts").document(user.uid).setData([
                    "uid": user.uid,
                    "firstName": self.firstNameField.text!,
                    "lastName": self.lastNameField.text!,
                    "email": email,
                    "birthday": Timestamp(date: self.birthdayField.date)
                ]) { err in
                    if let err = err {
                        self.errorMessage.text = "\(err.localizedDescription)"
                    } else {
                        print("Account saved with ID: \(user.uid)")
                            self.performSegue(
                                withIdentifier: "createPrefsSegueIdentifier",
                                sender: nil
                            )
                    }
                }
            }
        }
    }
}
