//
//  ForgotPassVC.swift
//  JobShop
//
//  Created by Olivia Mates on 10/21/26.
//

import UIKit
import FirebaseAuth

class ForgotPassVC: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    @IBOutlet weak var userEmail: UITextField!
   
    
    @IBAction func submitPressed(_ sender: Any) {
        let email: String = userEmail.text!
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            // Handle completion
        }

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
