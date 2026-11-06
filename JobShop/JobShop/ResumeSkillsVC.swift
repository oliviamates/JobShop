//
//  ResumeSkillsVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/5/26.
//

import UIKit

class ResumeSkillsVC: UIViewController {
    
    var extractedSkills: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        print("RESUME SKILLS VC LOADED!")
        print("Extracted skills:")
        for skill in extractedSkills {
            print("- \(skill)")
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
