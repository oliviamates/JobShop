import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateAccountVC: UIViewController {

    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    let db = Firestore.firestore()

    @IBAction func step1Done(_ sender: Any) {
        if firstNameField.text!.isEmpty || lastNameField.text!.isEmpty {
            makePopup(popupTitle: "Error", popupMessage: "Please enter your first and last name.")
            return
        }
        
        let email = emailField.text!.trimmingCharacters(in: .whitespaces)

        if email.isEmpty {
            makePopup(popupTitle: "Error", popupMessage: "Please enter your email.")
            return
        }

        if passwordField.text!.isEmpty {
            makePopup(popupTitle: "Error", popupMessage: "Please enter a password.")
            return
        }

        if passwordField.text!.count < 6 {
            makePopup(popupTitle: "Error", popupMessage: "Your password needs at least 6 characters.")
            return
        }

        Auth.auth().createUser(withEmail: email, password: passwordField.text!) {
            (authResult,error) in
            if let error = error as NSError? {
                self.makePopup(popupTitle: "Error", popupMessage: "\(error.localizedDescription)")
            } else {
                let user = authResult!.user

                self.db.collection("accounts").document(user.uid).setData([
                    "uid": user.uid,
                    "firstName": self.firstNameField.text!,
                    "lastName": self.lastNameField.text!,
                    "email": email
                ]) { err in
                    if let err = err {
                        self.makePopup(popupTitle: "Error",
                                       popupMessage: "\(err.localizedDescription)")
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

    func makePopup(popupTitle:String, popupMessage:String) {

        let controller = UIAlertController(
            title: popupTitle,
            message: popupMessage,
            preferredStyle: .alert)

        controller.addAction(UIAlertAction(title: "OK", style: .default))

        present(controller,animated:true)
    }
}
