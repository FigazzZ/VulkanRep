//
//  AboutViewController.swift
//  VULCAM eye
//
//  Created by Jonas Nikula on 20/09/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

import Foundation
import UIKit


class AboutViewController: UIViewController
{
    @IBOutlet weak var vulcamVersion: UILabel!
    @IBOutlet weak var vulcamCopyright: UILabel!
    @IBOutlet weak var licensesView: VUVLicensesView!
    
    @IBAction func showLibLicenses(_ sender: AnyObject)
    {
        licensesView.show();
    }
    
    @IBAction func exitAboutView(_ sender: AnyObject)
    {
        if licensesView.isHidden
        {
            self.dismiss(animated: true, completion:nil)
        }
        else
        {
            licensesView.close();
        }
    }
    
    override func viewDidLoad()
    {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let copyrightText = "© 2015-2016 Vulcan Vision Corporation. All rights reserved."
        
        vulcamVersion.text = version
        vulcamCopyright.text = copyrightText
    }
}
