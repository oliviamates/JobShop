//
//  LogInVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LogInVC: UIViewController {

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var errorMessage: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.emailField.text = ""
        self.passwordField.text = ""
        self.errorMessage.text = ""
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @IBAction func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func incrementLoginCount() async {
        guard let uid = Auth.auth().currentUser?.uid else {
                return
            }

            let db = Firestore.firestore()
            let userRef = db.collection("accounts").document(uid)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone.current

            let today = formatter.string(from: Date())

            do {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in

                    db.runTransaction({ transaction, errorPointer -> Any? in

                        do {
                            let snapshot = try transaction.getDocument(userRef)

                            let lastLoginDay = snapshot.data()?["lastLoginDay"] as? String ?? ""
                            let currentDays = snapshot.data()?["loginCount"] as? Int ?? 0

                            if lastLoginDay != today {

                                transaction.setData([
                                    "loginCount": currentDays + 1,
                                    "lastLoginDay": today
                                ], forDocument: userRef, merge: true)
                            }

                            return nil

                        } catch {
                            errorPointer?.pointee = error as NSError
                            return nil
                        }

                    }, completion: { _, error in

                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    })
                }

                print("Login days successfully updated!")

            } catch {
                print("Error updating login days: \(error)")
            }
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
                Task {
                    await self.incrementLoginCount()
                }
               
                DispatchQueue.main.async {
                               self.performSegue(withIdentifier: "goToMatches", sender: self)
                }
            }
        }
    }
}
