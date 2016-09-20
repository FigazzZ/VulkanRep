//
//  VUVAboutViewController.swift
//  VULCAM eye
//
//  Created by Jonas Nikula on 20/09/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

import Foundation
import UIKit


class VUVAboutViewController: UIViewController
{
    @IBOutlet weak var vulcamVersion: UILabel!
    @IBOutlet weak var vulcamCopyright: UILabel!
    @IBOutlet weak var licensesView: VUVLicensesView!
    
    @IBAction func showLibLicenses(sender: AnyObject)
    {
        licensesView.showLicensesView();
    }
    
    @IBAction func exitAboutView(sender: AnyObject)
    {
        if licensesView.hidden
        {
            self.dismissViewControllerAnimated(true, completion:nil)
        }
        else
        {
            licensesView.closeLicensesView();
        }
    }
    
    override func viewDidLoad()
    {
        let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        let copyrightText = "© 2015-2016 Vulcan Vision Corporation. All rights reserved."
        
        vulcamVersion.text = version
        vulcamCopyright.text = copyrightText
    }
}
