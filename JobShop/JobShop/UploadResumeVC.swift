//
//  UploadResumeVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import UniformTypeIdentifiers
import PDFKit
import SwiftTextDOCX


class UploadResumeVC: UIViewController, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var statusMessage: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        statusMessage.text = ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        statusMessage.text = ""
    }
    
    @IBAction func uploadButtonTapped(_ sender: Any) {
        let supportedTypes: [UTType] = [.pdf, UTType(filenameExtension: "docx")!]
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
        let fileExtension = fileURL.pathExtension.lowercased()
        // go through different text extraction process depending on file type
        if fileExtension == "pdf" {
            extractPDFText(url: fileURL)
        } else if fileExtension == "docx" {
            extractDOCXText(url: fileURL)
        } else {
            statusMessage.text = "Unsupported file type."
            statusMessage.textColor = .systemRed
        }
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
                statusMessage.text = "No text could be found in this PDF."
                statusMessage.textColor = .systemRed
                return
            }
            skillsFromResumeText(resumeText: extractedText)
        } else {
            statusMessage.text = "Error opening PDF."
            statusMessage.textColor = .systemRed
        }
    }
    
    // extract text from docx files
    func extractDOCXText(url: URL) {
        if let docxDocument = try? DocxFile(url: url) {
                let extractedText = docxDocument.plainText()
                if extractedText.isEmpty {
                    statusMessage.text = "No text could be found in this docx file."
                    statusMessage.textColor = .systemRed
                    return
                }
                skillsFromResumeText(resumeText: extractedText)
            } else {
                statusMessage.text = "Error opening docx file."
                statusMessage.textColor = .systemRed
        }
    }
    
    func skillsFromResumeText(resumeText: String) {
        statusMessage.text = "Extracting skills from your resume..."
        statusMessage.textColor = .darkGreen
        
        let resumeSkills = ResumeSkills()
        Task {
            do {
                let skills = try await resumeSkills.matchSkills(resumeText: resumeText)
                print("Matched skills: \(skills)")
                performSegue(withIdentifier: "ResumeToSkills", sender: skills)
            } catch {
                statusMessage.text = "Error extracting skills from resume! Please try again."
                statusMessage.textColor = .systemRed
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
