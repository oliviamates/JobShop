
import UIKit
import MapKit
import FirebaseAuth
import FirebaseFirestore

class CurrentLocationVC: UIViewController, UITableViewDelegate, UITableViewDataSource,
                         UISearchBarDelegate, MKLocalSearchCompleterDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorMessage: UILabel!
    @IBOutlet weak var successMessage: UILabel!

    let db = Firestore.firestore()
    let completer = MKLocalSearchCompleter()
    var results = [MKLocalSearchCompletion]()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        completer.delegate = self
        completer.resultTypes = .address

        errorMessage.text = ""
        successMessage.text = ""

        loadSavedLocation()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            results = []
            tableView.reloadData()
        } else {
            completer.queryFragment = searchText
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func savePressed(_ sender: Any) {
        successMessage.text = ""
        errorMessage.text = ""

        guard let location = searchBar.text,
              !location.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage.text = "Select a location first."
            return
        }

        saveLocation(location)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.filter { result in
            !result.title.contains(where: { $0.isNumber })
        }
        tableView.reloadData()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search error: \(error.localizedDescription)")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "LocationCellIdentifier",
            for: indexPath
        )

        var content = cell.defaultContentConfiguration()
        content.text = results[indexPath.row].title
        content.secondaryText = results[indexPath.row].subtitle
        cell.contentConfiguration = content

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        successMessage.text = ""
        errorMessage.text = ""

        let completion = results[indexPath.row]
        let request = MKLocalSearch.Request(completion: completion)

        MKLocalSearch(request: request).start { response, error in
            if let error = error {
                self.errorMessage.text = error.localizedDescription
                return
            }

            guard let placemark = response?.mapItems.first?.placemark else {
                self.errorMessage.text = "Unable to retrieve location."
                return
            }

            let city = placemark.locality ?? completion.title
            let state = placemark.administrativeArea ?? ""
            let location = state.isEmpty ? city : "\(city), \(state)"

            // Show selected location in search bar
            self.searchBar.text = location
            self.errorMessage.text = ""
            self.results = []
            self.tableView.reloadData()
            self.searchBar.resignFirstResponder()
        }
    }

    // Load previously saved location when user opens the screen
    func loadSavedLocation() {
        guard let user = Auth.auth().currentUser else { return }

        db.collection("accounts").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("Error retrieving location: \(error.localizedDescription)")
                return
            }

            guard let data = document?.data() else { return }

            if let location = data["currentLocation"] as? String {
                self.searchBar.text = location
            }
        }
    }

    // Save selected location to Firestore
    func saveLocation(_ name: String) {
        successMessage.text = ""

        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Error with saving new location!"
            return
        }

        db.collection("accounts").document(user.uid)
            .setData(["currentLocation": name], merge: true) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage.text = error.localizedDescription
                } else {
                    self.successMessage.text = "Location saved!"
                }
            }
    }
}

