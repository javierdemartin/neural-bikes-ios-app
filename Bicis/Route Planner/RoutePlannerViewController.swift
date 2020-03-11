//
//  RoutePlannerViewController.swift
//  Bicis
//
//  Created by Javier de Martín Gil on 09/03/2020.
//  Copyright © 2020 Javier de Martín Gil. All rights reserved.
//

import Foundation
import ReactiveCocoa
import ReactiveSwift
import UIKit
import MapKit

extension RoutePlannerViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {

        filteredData = Array(self.viewModel.stationsDict.keys)

        if searchText.isEmpty == false {
            filteredData = Array(self.viewModel.stationsDict.keys).filter({ $0.lowercased().contains(searchText.lowercased()) })
        }

        if filteredData.count > 0 {
            tableView.isHidden = false
        } else if filteredData.count == 0 {
            tableView.isHidden = true
        }

        tableView.reloadData()
    }
}

extension RoutePlannerViewController: RoutePlannerViewModelDelegate {

    func gotRouteCalculations(route: MKRoute) {

        destinationStationVerticalStackView.isHidden = false
        startTripButton.isHidden = false

        distanceToDestinationLabel.text = "\(Double(round(100*route.distance/1000)/100))"
        timeToDestinationLabel.text = "\(route.expectedTravelTime.minutes)"

        freeRacksOnDestinationLabel.text = "\(self.viewModel.destinationStation!.freeRacks)"
        destinationStationLabel.text = "\(self.viewModel.destinationStation!.stationName)"

        viewModel.calculateRmseForStationByQueryingPredictions(completion: {

            if let rmseOfStation = self.viewModel.destinationStation!.inverseAccuracyRmse {

                self.scoreOfDestinationLabel.text = "\(Int(rmseOfStation))"
            }

            // Calculate the predicted availability at the arrival time
            if self.viewModel.destinationStation!.availabilityArray!.count > 0 && self.viewModel.destinationStation!.predictionArray!.count > 0 {
                let remainderPredictionOfTheDay = self.viewModel.destinationStation!.predictionArray![(self.viewModel.destinationStation!.availabilityArray!.count)...]
                print(remainderPredictionOfTheDay.count)

                // Current time
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "hh:mm"

                // Replace last character by a 0, round to the nearest 10' interval
                var roundedArrivalTime = dateFormatter.string(from: Date())
                var arrayCharsOfTime = Array(roundedArrivalTime)
                arrayCharsOfTime[arrayCharsOfTime.count - 1] = "0"

                roundedArrivalTime = String(arrayCharsOfTime)

                guard let indexOfTime = Constants.listHours.firstIndex(of: roundedArrivalTime) else { return }

                // Calculate the availability at arrival
                self.predictedDocksAtDestinationLabel.text = "\(self.viewModel.destinationStation!.totalAvailableDocks - self.viewModel.destinationStation!.predictionArray![indexOfTime])"
            }
        })
    }

    func selectedDestination(station: BikeStation) {

    }

    func presentAlertViewWithError(title: String, body: String) {

        let alertController = UIAlertController(title: title, message: body, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }
}

extension  RoutePlannerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        cell.selectionStyle = UITableViewCell.SelectionStyle.default
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        cell.textLabel?.text = "\(filteredData[indexPath.row])"
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .regular)

        if let freeRacks = viewModel.stationsDict[filteredData[indexPath.row]]?.freeRacks {

            cell.detailTextLabel?.text = "FREE_DOCKS_AT_DESTINATION_LABEL".localize(file: "RoutePlanner").replacingOccurrences(of: "%number", with: "\(freeRacks)")
        } else {
            cell.detailTextLabel?.text = "ERROR_LOADING_FREE_DOCKS_AT_DESTINATION".localize(file: "RoutePlanner")
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Selected \(filteredData[indexPath.row])")

        tableView.isHidden = true

        viewModel.selectedDestinationStation(name: filteredData[indexPath.row])

        // Hides the keboard as the search has been completed
        searchBar.resignFirstResponder()
    }
}

class RoutePlannerViewController: UIViewController {

    let viewModel: RoutePlannerViewModel
    let compositeDisposable: CompositeDisposable
    var filteredData: [String]

    let pullTabToDismissView: UIView = {

        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray
        view.layer.cornerRadius = 2.5
        return view
    }()

    let instructionsTextField: UITextView = {

        let textView = UITextView(frame: .zero, textContainer: nil)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.isSelectable = false
        textView.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.sizeToFit()
        textView.isUserInteractionEnabled = true
        textView.text = "ROUTE_PLANNER_INSTRUCTIONS_TEXT_FIELD".localize(file: "RoutePlanner")
        return textView
    }()

//    let scrollView: UIScrollView = {
//
//        let scrollView = UIScrollView(frame: .zero)
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        scrollView.backgroundColor = .clear
//        scrollView.scrollsToTop = false
//        scrollView.delaysContentTouches = false
//        scrollView.showsVerticalScrollIndicator = false
//        scrollView.alwaysBounceVertical = true
//        scrollView.isDirectionalLockEnabled = true
//
//        return scrollView
//    }()

    let searchBar: UISearchBar = {

        let searchBar = UISearchBar()
        searchBar.backgroundImage = UIImage() // Removes top and bottom lines
        searchBar.placeholder = "STATION_SEARCH_PLACEHOLDER".localize(file: "RoutePlanner")
        return searchBar
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.showsVerticalScrollIndicator = false
        tableView.isUserInteractionEnabled = true
        tableView.delaysContentTouches = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        return tableView
    }()

    lazy var verticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [instructionsTextField, destinationStationVerticalStackView, searchBar])
        stackView.alignment = UIStackView.Alignment.center
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var destinationStationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [labelsDestinationStationVerticalStackView, statisticsVerticalStackView, startTripButton])
        stackView.alignment = UIStackView.Alignment.top
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.isHidden = true
        stackView.distribution  = UIStackView.Distribution.equalCentering
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var statisticsVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [timeToDestinationVerticalStackView, distanceToDestinationVerticalStackView, freeRacksOnDestinationVerticalStackView, predictedDocksAtDestinationVerticalStackView, scoreOfDestinationVerticalStackView])
        stackView.alignment = UIStackView.Alignment.center
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.horizontal
        stackView.isHidden = false
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 20.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var distanceToDestinationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [distanceToDestinationLabel, distanceToDestinationUnitsLabel])
        stackView.alignment = UIStackView.Alignment.center
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var distanceToDestinationLabel: UILabel = {

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "XX"

        return label
    }()

    lazy var distanceToDestinationUnitsLabel: UILabel = {

        let label = UILabel()

        label.text = "km."
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        return label
    }()

    lazy var freeRacksOnDestinationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [freeRacksOnDestinationLabel, freeRacksOnDestinationUnitsLabel])
        stackView.alignment = UIStackView.Alignment.center
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var freeRacksOnDestinationLabel: UILabel = {

        let label = UILabel()
        label.text = "XX"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    lazy var freeRacksOnDestinationUnitsLabel: UILabel = {

        let label = UILabel()

        label.text = "anclajes"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var timeToDestinationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [timeToDestinationLabel, timeToDestinationUnitsLabel])
        stackView.alignment = UIStackView.Alignment.center
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var timeToDestinationLabel: UILabel = {

        let label = UILabel()
        label.text = "XX"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var timeToDestinationUnitsLabel: UILabel = {

        let label = UILabel()

        label.text = "min."
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        return label
    }()

    lazy var labelsDestinationStationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [destinationStationLabel,destinationStationUnitsLabel])
        stackView.alignment = UIStackView.Alignment.leading
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView

    }()

    let destinationStationLabel: UILabel = {

        let label = UILabel()
        label.text = "Station Name"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)

        return label
    }()

    let destinationStationUnitsLabel: UILabel = {

        let label = UILabel()
        label.text = "Estación de destino".uppercased()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13.0, weight: .regular)

        return label
    }()

    lazy var startTripButton: UIButton = {

        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 9.0
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        button.isHidden = true

        button.setTitle("START_TRIP".localize(file: "RoutePlanner"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var scoreOfDestinationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [scoreOfDestinationLabel, scoreOfDestinationUnitsLabel])
        stackView.alignment = UIStackView.Alignment.center
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var scoreOfDestinationLabel: UILabel = {

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "XX"

        return label
    }()

    lazy var scoreOfDestinationUnitsLabel: UILabel = {

        let label = UILabel()

        label.text = "acc (%)"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var predictedDocksAtDestinationVerticalStackView: UIStackView = {

        let stackView = UIStackView(arrangedSubviews: [predictedDocksAtDestinationLabel, predictedDocksAtDestinationUnitsLabel])
        stackView.alignment = UIStackView.Alignment.center
        stackView.backgroundColor = .white
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.distribution  = UIStackView.Distribution.equalSpacing
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    lazy var predictedDocksAtDestinationLabel: UILabel = {

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "YY"

        return label
    }()

    lazy var predictedDocksAtDestinationUnitsLabel: UILabel = {

        let label = UILabel()

        label.text = "@ time"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(viewModel: RoutePlannerViewModel, compositeDisposable: CompositeDisposable) {

        self.viewModel = viewModel
        self.compositeDisposable = compositeDisposable
        self.filteredData = []

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        view = UIView()
        view.backgroundColor = .systemBackground

        view.addSubview(pullTabToDismissView)
        view.addSubview(verticalStackView)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            pullTabToDismissView.heightAnchor.constraint(equalToConstant: 5),
            pullTabToDismissView.widthAnchor.constraint(equalToConstant: 40),
            pullTabToDismissView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            pullTabToDismissView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16.0)
        ])

        NSLayoutConstraint.activate([
            verticalStackView.topAnchor.constraint(equalTo: pullTabToDismissView.bottomAnchor, constant: 16.0),
            verticalStackView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            verticalStackView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0)
        ])

        NSLayoutConstraint.activate([
            startTripButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])

        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            searchBar.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
        ])

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            tableView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
            tableView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: verticalStackView.bottomAnchor, constant: 16.0),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // When the view is loaded pop up the keyboard for faster interaction
        searchBar.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.delegate = self
        searchBar.delegate = self
        tableView.register(RoutePlannerTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self

        self.searchBar(searchBar, textDidChange: "")

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//        view.addGestureRecognizer(tap)

        setUpBindings()
    }

    func setUpBindings() {

        compositeDisposable += startTripButton.reactive.controlEvents(.touchUpInside).observeValues({ [weak self] (_) in

            guard let self = self else { fatalError() }

            self.viewModel.checkUserNotificationStatus()
        })
    }

    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }

    @objc func keyboardWillShow(sender: NSNotification) {

        if let keyboardFrame: NSValue = sender.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height

//            self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)

            // Moves the view to the next active view if it's out of the scope
//            self.verticalScrollView.scrollRectToVisible(confirmationCodeTextField.frame, animated: true)
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {

        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
//        scrollView.contentInset = contentInset
    }
}
