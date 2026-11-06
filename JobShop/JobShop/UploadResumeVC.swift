//
//  UploadResumeVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import UniformTypeIdentifiers
import PDFKit


class UploadResumeVC: UIViewController, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func uploadButtonTapped(_ sender: Any) {
        let supportedTypes: [UTType] = [.pdf]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true, completion: nil)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedFileURL = urls.first else { return }
            uploadFile(fileURL: selectedFileURL)
        }
    
    func uploadFile(fileURL: URL) {
        // keeping extractPDFText as separate function so we can add support for docx later on!
        extractPDFText(url: fileURL)
    }
    
    // extract text from pdf files with text
    func extractPDFText(url: URL) {
        if let pdfDocument = PDFDocument(url: url) {
            var extractedText = ""
            for pageIndex in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: pageIndex) {
                    if let pageText = page.string {
                        extractedText += pageText + "\n"
                    }
                }
            }
            
            if extractedText.isEmpty {
                print("No text could be extracted from this PDF.")
                return
            }
            
            print(extractedText)
            skillsFromResumeText(resumeText: extractedText)
        } else {
            print("error opening PDF")
        }
    }
    
    func skillsFromResumeText(resumeText: String) {
        let resumeSkills = ResumeSkills()
        Task {
            do {
                let skills = try await resumeSkills.matchSkills(resumeText: resumeText)
                print("Matched skills: \(skills)")
                performSegue(withIdentifier: "ResumeToSkills", sender: skills)
            } catch {
                print("resume matching FAILED")
            }
        }
    }
    @IBAction func openCamera(_ sender: Any) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = .camera
                present(picker, animated: true, completion: nil)
            } else {
                print("Camera not available on this device.")
            }
        }
    

    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ResumeToSkills" {
            let destination = segue.destination as! ResumeSkillsVC
            destination.extractedSkills = sender as! [String]
        }
    }
}
