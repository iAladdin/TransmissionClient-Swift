//
//  TaskListViewController.swift
//  TransmissionClient-Swift
//
//  Created by SUN on 15/11/24.
//  Copyright © 2015年 SUN. All rights reserved.
//

import UIKit
import CNPPopupController
import Alamofire
import SwiftyJSON

class TaskListViewController: UITableViewController,CNPPopupControllerDelegate {
    
    var siteUrl:String!
    
    var author:String?
    
    var sessionId:String!
    
    private var popupController : CNPPopupController?
    
    private var tasks : [TaskVO] = []
    
    override func viewDidLoad() {
        
        let nib=UINib(nibName: "TaskListTableViewCell", bundle: nil)
        self.tableView.registerNib(nib, forCellReuseIdentifier: "taskListTableViewCell")
        
        //实例化 popupController
        initPopupController()
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.setToolbarHidden(true, animated: true)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        self.navigationController?.setToolbarHidden(false, animated: true)
        
        var headers:[String:String] = [:]
        headers["X-Transmission-Session-Id"] = sessionId
        
        if let _author = author {
            headers["Authorization"] = _author
        }

        
        Alamofire.Manager.sharedInstance.request(Method.POST, siteUrl + BASE_URL, parameters: [:], encoding: ParameterEncoding.Custom({ (convertible, params) -> (NSMutableURLRequest, NSError?) in
            /// 这个地方是用来手动的设置POST消息体的,思路就是通过ParameterEncoding.Custom闭包来设置请求的HTTPBody
            let mutableRequest = convertible.URLRequest.copy() as! NSMutableURLRequest
            mutableRequest.HTTPBody = "{\"method\":\"torrent-get\",\"arguments\":{\"fields\":[\"id\",\"name\",\"error\",\"errorString\",\"peersConnected\",\"peersGettingFromUs\",\"percentDone\",\"sizeWhenDone\",\"totalSize\",\"status\",\"uploadRatio\",\"uploadedEver\",\"rateDownload\",\"rateUpload\",\"leftUntilDone\"]}}".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            return (mutableRequest, nil)
        }), headers: headers).responseJSON { (_, response, data) -> Void in
            if response?.statusCode == 200 {
                self.tasks.removeAll()
                if  let result = data.value {
                    let json = JSON(result)
                    print("data:\(json)")
                    let torrents = json["arguments"]["torrents"].array
                    
                    for torrent in torrents! {
                        self.tasks.append(self.convertJson2TaskVO(torrent))
                    }
                }
                self.tableView.reloadData()
            }
            
        }
        
    }
    
    /**
     把JSON对象转换成为TaskVO
     
     - parameter json:
     
     - returns:
     */
    private func convertJson2TaskVO(json:JSON) -> TaskVO {
        let id = json["id"].intValue
        let name = json["name"].stringValue
        
        let task = TaskVO(id: id, name: name)
        
        task.error = json["error"].intValue
        task.errorString = json["errorString"].stringValue
        task.peersConnected = json["peersConnected"].intValue
        task.peersGettingFromUs = json["peersGettingFromUs"].intValue
        task.percentDone = json["percentDone"].floatValue
        task.sizeWhenDon = json["sizeWhenDon"].intValue
        task.totalSize = json["totalSize"].intValue
        task.status = json["status"].intValue
        task.uploadRatio = json["uploadRatio"].floatValue
        task.uploadedEver = json["uploadedEver"].intValue
        task.rateDownload = json["rateDownload"].intValue
        task.rateUpload = json["rateUpload"].intValue
        task.leftUntilDone = json["leftUntilDone"].intValue
        
        return task
    }
    
    private func initPopupController(){
        
        /// 实例化SharePopupView 弹出视图
        let view = UINib(nibName: "StatusPopupView", bundle: nil).instantiateWithOwner(nil, options: nil)[0] as? StatusPopupView
        /// 设置弹出视图的大小
        view?.frame = CGRectMake(0, 0, self.view.frame.width, 100)
        
        /// 设置弹出视图中 取消操作的 动作闭包
        view?.cancelHandel = {self.popupController?.dismissPopupControllerAnimated(true)}
        
        /// 实例化弹出控制器
        self.popupController = CNPPopupController(contents: [view!])
        self.popupController!.theme = CNPPopupTheme.defaultTheme()
        /// 设置点击背景取消弹出视图
        self.popupController!.theme.shouldDismissOnBackgroundTouch = true
        self.popupController!.theme.popupStyle = CNPPopupStyle.ActionSheet
        self.popupController!.theme.presentationStyle = CNPPopupPresentationStyle.SlideInFromTop
        //设置最大宽度,否则可能会在IPAD上出现只显示一半的情况,因为默认就只有300宽
        self.popupController!.theme.maxPopupWidth = self.view.frame.width
        /// 设置视图的边框
        self.popupController!.theme.popupContentInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        self.popupController!.delegate = self;
        
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var tmp = tableView.dequeueReusableCellWithIdentifier("taskListTableViewCell") as? TaskListTableViewCell
        
        if (tmp == nil) {
            tmp = TaskListTableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "taskListTableViewCell")
        }
        
        let task = tasks[indexPath.row]
        
        tmp?.nameLabel.text = task.name
        
        var desc:String
        var status:String
        
        if task.error > 0 {
            desc = task.errorString!
            status = ""
            tmp?.descLabel.textColor = UIColor.redColor()
            tmp?.progressView.progressTintColor = UIColor.grayColor()
        }else {
            tmp?.descLabel.textColor = UIColor.grayColor()
            switch task.status {
            case 4 :
                //下载
                tmp?.progressView.progressTintColor = UIColor.blueColor()
                desc = "从\(task.peersConnected)个peers进行下载 - ↓\(SpeedStringFormatter.formatSpeedToString(task.rateDownload))/s ↑\(SpeedStringFormatter.formatSpeedToString(task.rateUpload))/s"
                status = "已下载\(SpeedStringFormatter.formatSpeedToString(task.sizeWhenDon-task.leftUntilDone)),总共大小\(SpeedStringFormatter.formatSpeedToString(task.sizeWhenDon))(\(task.percentDone)%) - 预计剩余\(SpeedStringFormatter.clcaultHoursToString(task.leftUntilDone, speed: task.rateDownload))"
            default :
                tmp?.progressView.progressTintColor = UIColor(red: 0.173, green: 0.698, blue: 0.212, alpha: 1.000)
                desc = "为\(task.peersConnected)个Peers做种中 - ↑\(SpeedStringFormatter.formatSpeedToString(task.rateUpload))/s"
                status = "文件大小\(SpeedStringFormatter.formatSpeedToString(task.totalSize)),已上传\(SpeedStringFormatter.formatSpeedToString(task.uploadedEver)) (比率 \(task.uploadRatio))"
            }
        }
        
        tmp?.descLabel.text = desc
        tmp?.progressView.progress = task.percentDone
        tmp?.statusLabel.text = status
        
        return tmp!
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 100
    }
    
//    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        if  section == 0 {
//            return 60
//        }
//        return 60
//    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        self.performSegueWithIdentifier("showTaskDetailSegue", sender: nil)
    }
    
    @IBAction func doStatusAction(sender: UIBarButtonItem) {
        self.popupController?.presentPopupControllerAnimated(true)
    }
    
    //========================CNPPopupControllerDelegate的实现================================================
    
    //========================CNPPopupControllerDelegate的实现================================================
    
}