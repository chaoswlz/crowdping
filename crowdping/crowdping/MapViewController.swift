//
//  ViewController.swift
//  crowdping
//
//  Created by D'Arcy Smith on 2016-09-23.
//  Copyright © 2016 TerraTap Technologies, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import Contacts

class MapViewController: UIViewController, MKMapViewDelegate
{
    @IBOutlet weak var notifyCircle: UIButton!
    let notificationCentre = NotificationCenter.default
    var beaconNearbyObserver : AnyObject?
    var beaconNotNearbyObserver : AnyObject?
    var beaconRangedObserver : AnyObject?
    var beaconNotRangedObserver : AnyObject?
    var locationUpdatedObserver : AnyObject?
    
    @IBOutlet weak var timeView: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var notifySwitch: UISwitch!
    @IBOutlet weak var circleButton: UIButton!
    @IBOutlet weak var policeButton: UIButton!
    fileprivate var annotations : [MKAnnotation] = []
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        beaconNearbyObserver = notificationCentre.addObserver(forName: NSNotification.Name(rawValue: Notifications.BeaconNearby),
                                                              object: nil,
                                                              queue: nil)
        {
            (note) in
            let location = Notifications.getLocation(note)
            print("BeaconNearby received \(location)")
            
            if let location = location
            {
                self.beaconNearby(location)
            }
        }
        
        beaconNotNearbyObserver = notificationCentre.addObserver(forName: NSNotification.Name(rawValue: Notifications.BeaconNotNearby),
                                                              object: nil,
                                                              queue: nil)
        {
            (note) in
            let location = Notifications.getLocation(note)
            print("BeaconNotNearby received \(location)")
            
            if let location = location
            {
                self.beaconNotNearby(location)
            }
        }
        
        beaconRangedObserver = notificationCentre.addObserver(forName: NSNotification.Name(rawValue: Notifications.BeaconRanged),
                                                              object: nil,
                                                              queue: nil)
        {
            (note) in
            let rssi = Notifications.getRssi(note)
            print("BeaconRanged received \(rssi)")
            
            if let rssi = rssi
            {
                self.beaconRanged(rssi)
            }
        }
        
        beaconNotRangedObserver = notificationCentre.addObserver(forName: NSNotification.Name(rawValue: Notifications.BeaconNotRanged),
                                                                 object: nil,
                                                                 queue: nil)
        {
            (note) in
            print("BeaconNotRanged received")
            self.beaconNotRanged()
        }
        
        locationUpdatedObserver = notificationCentre.addObserver(forName: NSNotification.Name(rawValue: Notifications.LocationUpdated),
                                                                 object: nil,
                                                                 queue: nil)
        {
            (note) in
            let location = Notifications.getLocation(note)
            print("LocationUpdated received \(location)")
            
            if let location = location
            {
                self.locationUpdated(location)
            }
        }
        
        mapView.delegate          = self
        mapView.showsUserLocation = true
        mapView.showsScale        = true
        
        if State.isSearching
        {
            updateTime()
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        notifySwitch.isOn      = State.isSearching
        circleButton.isEnabled = State.isSearching
        policeButton.isEnabled = State.isSearching
        
        if State.isSearching
        {
            State.timer = Timer.scheduledTimer(timeInterval: 1,
                                               target: self,
                                               selector: #selector(updateTime),
                                               userInfo: nil,
                                               repeats: true)
            updateTime()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        Notifications.removeObserver(beaconNearbyObserver,    from: notificationCentre)
        Notifications.removeObserver(beaconNotNearbyObserver, from: notificationCentre)
        Notifications.removeObserver(beaconRangedObserver,    from: notificationCentre)
        Notifications.removeObserver(beaconNotRangedObserver, from: notificationCentre)
        Notifications.removeObserver(locationUpdatedObserver, from: notificationCentre)
    }

    @IBAction func notifySwitchChanged(_ sender: AnyObject)
    {
        if notifySwitch.isOn
        {
            Notifications.postStartLocationMonitoring(self)
            Notifications.postStartBeaconMonitoring(self)
            State.timer = Timer.scheduledTimer(timeInterval: 1,
                                     target: self,
                                     selector: #selector(updateTime),
                                     userInfo: nil,
                                     repeats: true)
            State.startTime = NSDate()
        }
        else
        {
            Notifications.postStopLocationMonitoring(self)
            Notifications.postStopBeaconMonitoring(self)
            State.timer?.invalidate()
            State.timer = nil
            State.startTime = nil
        }
        
        State.isSearching      = notifySwitch.isOn
        circleButton.isEnabled = notifySwitch.isOn
        policeButton.isEnabled = notifySwitch.isOn
    }
    
    @IBAction func notifyCircle(_ sender: AnyObject)
    {
        let alertController = UIAlertController(
            title: "Notify Circle",
            message: "Notify the members of your circle to help you find <person>?",
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel)
        {
            (action) in
        }
        alertController.addAction(cancelAction)
        
        let OKAction = UIAlertAction(
            title: "OK",
            style: .default)
        {
            (action) in
            State.sendNotificationToCircle()
        }
        alertController.addAction(OKAction)
        
        present(alertController, animated: true)
        {
        }
    }
    
    @IBAction func notifyPolice(_ sender: AnyObject)
    {
        let alertController = UIAlertController(
            title: "Call the Police",
            message: "Call the police to help you find <person>?",
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel)
        {
            (action) in
        }
        alertController.addAction(cancelAction)
        
        let OKAction = UIAlertAction(
            title: "OK",
            style: .default)
        {
            (action) in
            State.callPolice()
        }
        alertController.addAction(OKAction)
        
        present(alertController, animated: true)
        {
        }
    }
    
    // MARK: internal
    
    fileprivate func beaconNearby(_ location: CLLocation!)
    {
        print("beaconNearby \(location)")
        addLocation(location, found: true)
        
        let rangeViewController = self.storyboard?.instantiateViewController(withIdentifier: "range") as! RangeViewController
        self.present(rangeViewController, animated: false)
    }
    
    fileprivate func beaconNotNearby(_ location: CLLocation!)
    {
        print("beaconNotNearby \(location)")
        addLocation(location, found: false)
    }
    
    fileprivate func beaconRanged(_ rssi: Int)
    {
        print("beaconRanged \(rssi)")
        State.beaconFound = true
    }
    
    fileprivate func beaconNotRanged()
    {
        print("beaconNotRanged")
        State.beaconFound = false
    }
    
    fileprivate func locationUpdated(_ location: CLLocation!)
    {
        print("locationUpdated \(location)")
        
        addLocation(location, found: State.beaconFound)
        
        if State.beaconFound
        {
        }
        else
        {
        }
    }
    
    fileprivate func clearAnnotations()
    {
        mapView.removeAnnotations(annotations)
        annotations.removeAll()
    }
    
    func addLocation(_ location : CLLocation, found : Bool)
    {
        let annotation  = LocationAnotation(location.coordinate, found: found)
        
        annotations.append(annotation)
        mapView.addAnnotations(annotations)
        mapView.showAnnotations(annotations, animated: true)
        mapView.camera.altitude *= 1.5
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        // log.debug("enter")
        
        if let _ = annotation as? MKUserLocation
        {
            // log.debug("exit")
            return nil
        }
        
        var view: MKPinAnnotationView
        let identifier = "pin"
        
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            as? MKPinAnnotationView
        {
            dequeuedView.annotation = annotation
            view                    = dequeuedView
        }
        else
        {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = false
            
//            view.canShowCallout = true
//            view.calloutOffset  = CGPoint(x: -5, y: 5)
//            view.rightCalloutAccessoryView  = UIButton(type: .detailDisclosure) as UIView
        }
        
        if let annotation = annotation as? LocationAnotation
        {
            if annotation.found
            {
                view.pinTintColor = UIColor.green
            }
            else
            {
                view.pinTintColor = UIColor.red
            }
        }
        
        return view
    }
    
    func mapView(_ mapView: MKMapView,
                 annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl)
    {
        let _ = view.annotation as! LocationAnotation
    }
    /*
    func mapItem(_ view : MKAnnotationView) -> MKMapItem
    {
        let addressDictionary = [String(CNPostalAddressStreetKey) : view.annotation!.title!!]
        let placemark = MKPlacemark(coordinate: view.annotation!.coordinate, addressDictionary: addressDictionary)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        
        return mapItem
    }
    */
    
    func updateTime()
    {
        let interval = State.startTime!.timeIntervalSinceNow * -1
        let ti       = Int(interval)
        let seconds  = (ti % 60)
        let minutes  = (ti / 60) % 60
        let hours    = (ti / 3600)
        let str : String!
        
        if minutes < 2
        {
            str = String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
        }
        else
        {
            str = String(format: "%0.2d:%0.2d", hours, minutes)
        }
        
        timeView.text = str
    }
}