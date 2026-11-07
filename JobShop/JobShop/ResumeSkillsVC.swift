//
//  ResumeSkillsVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/5/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ResumeSkillsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorMessage: UILabel!
    
    var extractedSkills: [String] = []
    var selectedSkills: [String] = []
    
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        errorMessage.text = ""
        loadNewSkills()
    }
    
    @IBAction func savePressed(_ sender: Any) {
        errorMessage.text = ""
        if let user = Auth.auth().currentUser {
            db.collection("accounts").document(user.uid)
                .updateData([
                    // combine selected skills with existing skills in firestore
                    "skills": FieldValue.arrayUnion(selectedSkills)
                ]) { err in
                    if let err = err {
                        self.errorMessage.text = err.localizedDescription
                    } else {
                        self.dismiss(animated: true)
                    }
                }
        } else {
            errorMessage.text = "Error saving skills."
        }
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    func loadNewSkills() {
        
        if let user = Auth.auth().currentUser {
            db.collection("accounts").document(user.uid).getDocument { [weak self] document, err in
                if let self = self {
                    if let err = err {
                        self.errorMessage.text = err.localizedDescription
                        return
                    }

                    // retrieve existing skills in profile
                    let existingSkills = document?.data()?["skills"] as? [String] ?? []

                    // only show extracted skills that aren't already in existing skills
                    self.extractedSkills = self.extractedSkills.filter { skill in
                        !existingSkills.contains(where: {
                            $0.caseInsensitiveCompare(skill) == .orderedSame
                        })
                    }
                    self.tableView.reloadData()
                    if self.extractedSkills.isEmpty {
                        self.errorMessage.text = "No additional skills were found in your resume!"
                    }
                }
            }
        } else {
            errorMessage.text = "Error loading profile skills."
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return extractedSkills.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "ExtractedSkillIdentifier",
            for: indexPath
        )

        let skill = extractedSkills[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = skill
        
        // show filled in vs. empty circle depending on whether a skill is selected
        if selectedSkills.contains(skill) {
            content.image = UIImage(systemName: "checkmark.circle.fill")
            content.imageProperties.tintColor = UIColor(named: "DarkGreen")
        } else {
            content.image = UIImage(systemName: "circle")
            content.imageProperties.tintColor = .systemGray
        }

        cell.contentConfiguration = content
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let skill = extractedSkills[indexPath.row]
        
        // select or deselect skills
        if selectedSkills.contains(skill) {
            if let index = selectedSkills.firstIndex(of: skill) {
                selectedSkills.remove(at: index)
            }
        } else {
            selectedSkills.append(skill)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
