//
//  RR_AD.swift
//  RRPlayer
//
//  Created by SLboat on 2018/1/13.
//  Copyright © 2018年 lhc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

/// 广告调试
let DEBUG_FOR_AD:Bool = true

///广告地址
struct AdURL {
  ///初始化地址
  static let adinitURL = URL(string: "https://xxx.zmzapi.com/init")!
  ///完整广告地址
  static let adsURL = URL(string: "https://xxx.zmzapi.com/ads")!
}

//广告打印
func dlog(_ objs: CustomStringConvertible...){
  guard DEBUG_FOR_AD else { return }
  var desc = ""
  for obj in objs{
    desc += obj.description
  }
  ADLog.shared.write(desc)
  print("[广告引擎]\(desc)")
}

///日志
class ADLog {
  ///单例
  static let shared = ADLog()
  
  //TODO: 记事本打开日志
  
  ///当前日志
  var logs: String = ""
  
  /// 时间机器
  private let fm: DateFormatter = {
    let fm = DateFormatter()
    fm.dateFormat = "[yy-MM-dd HH:mm]" //得到 8/1/16 20:47
    return fm
  }()
  
  ///日志文件
  let logFileURL: URL = {
    let url = Utility.appSupportDirUrl.appendingPathComponent(("debug_ad.log"))
    return url
  }()
  
  ///写日志
  func write(_ log: String){
    let dStr = fm.string(from: Date())
    logs += "\n" + dStr + log
    _ = try? logs.write(to: self.logFileURL, atomically: true, encoding: .utf8)
  }
  
  ///初始化
  private init(){
    //self.logs = (try? String(contentsOf: self.logFileURL, encoding: .utf8)) ?? ""
  }
}

/// AD工作者
class ADMan{
  ///单例
  static let shared = ADMan()
  
  ///广告文件夹目录
  static let workURL: URL = {
    let url = Utility.appSupportDirUrl.appendingPathComponent("yy_ad")
    Utility.createDirIfNotExist(url: url) //创建目录
    return url
  }()
  
  /// 正在使用网络
  var isUsingNetWork: Bool = false
  
  /// 最后下载时间
  var lastDownload: TimeInterval?
  
  ///短超时会话
  let lessTimeOutAlamofire: SessionManager = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = RRModFlag.networkTIMEOUTSec
    
    let sessionManager = Alamofire.SessionManager(configuration: configuration)
    return sessionManager
  }()
  
  ///广告信息
  var info: ADInfo?
  
  private init() {
    dlog("开始初始化广告引擎,工作目录: ~/Library/Application Support/com.yyets.rrplayer")
    self.loadAdData() //载入
    self.updateAdData() //更新广告

    //self.makeFakeData()
  }
}

//MARK: 下载等模块
extension ADMan{
  ///本地信息
  private var localInfoURL: URL{
    return ADMan.workURL.appendingPathComponent("info")
  }
  
  ///是否信息文件存在
  var isInfoFileExsit: Bool{
    return FileManager.default.fileExists(atPath: localInfoURL.path)
  }
  
  ///清空广告数据
  func cleanAdData(){
    dlog("清空当前广告文件数据")
    _ = try? FileManager.default.removeItem(at: ADMan.workURL)
    Utility.createDirIfNotExist(url: ADMan.workURL) //创建目录
  }
  
  ///载入广告数据
  func loadAdData(){
    dlog("载入本地广告数据")
    self.info = nil //清空旧数据
    guard FileManager.default.fileExists(atPath: localInfoURL.path) else {
      return
    }
    if let data = try? Data(contentsOf: localInfoURL), let localJson = try? JSON(data: data){
      self.readFromJson(localJson)
    }
  }
  
  ///本地写入
  func saveAdData(_ json: JSON){
    dlog("写入本地广告信息")
    //删除本地已有,必要的话...
    _ = try? json.rawData().write(to: localInfoURL, options: .atomic)
  }
  
  ///从JSON读取
  func readFromJson(_ json: JSON){
    //新信息
    let info = ADInfo()
    info.lastAdUpdateTime = json["adUpdateTime"].stringValue //记录最后更新
    let adsJson =  json["ads"]
    guard !adsJson.isEmpty else {
      dlog("[解析广告]JSON数据没有ads字段,无法解析")
      return
    }
    //开始搞广告
    for (_, ad):(String, JSON) in adsJson{
      let videoURL = ad["video"].url
      let picURL = ad["pic"].url
      if videoURL == nil, picURL == nil{
        dlog("[解析广告JSON][错误]服务器有一条没有图片和视频地址的广告数据,丢弃")
        continue
      }
      /// 新广告
      let newAD = SingleAD()
      newAD.adID = ad["adId"].int ?? 0 //垃圾数据
      if let url = ad["click"].url{
        newAD.clickLink = url
      }
      //常规赋值
      newAD.wh = ad["wh"].string
      newAD.showTime = ad["showTime"].int
      
      //通用图片路径
      if let picURL = picURL{
        newAD.srcURL = picURL //记录地址
        newAD.adType = .pic //类型
      }
      if ad["adType"].intValue == 1{ //片头广告解读
          if let duuartion = ad["duration"].int{
            newAD.duartion = duuartion
          }else{
            dlog("[解析广告JSON][错误]服务器没有指定片头视频广告长度,使用10秒")
            newAD.duartion = 10
          }
          if let videoURL = videoURL{
            newAD.adType = .video
            newAD.fileName = "st.mp4" //文件名
            newAD.srcURL = videoURL //记录地址
            info.startVideoAD = newAD
          }else{
            info.startPicAD = newAD
        }
      }else if ad["adType"].intValue == 2{ //暂停广告解读
        info.pausePicAD = newAD
      }else{
        dlog("[解析广告JSON][不支持]不支持的adType: \(ad["adType"].stringValue)")
      }
    }
    //赋予信息
    self.info = info
    //扫描媒体
    self.scanAndDownloadMedia()
  }
  
  ///扫描需要的媒体文件
  func scanAndDownloadMedia(){
    guard !self.isUsingNetWork else {
      return
    }
    if let lastDownload = lastDownload{
      let nowInteval = Date().timeIntervalSinceReferenceDate
      let diffInteval = Int(nowInteval - lastDownload)
      if diffInteval < 30{
        dlog("[终止]两次扫描媒体\(diffInteval)时间太短,放弃.")
        return
      }
    }
    dlog("正在扫描本地广告媒体文件完整...")
    lastDownload = Date().timeIntervalSinceReferenceDate //记录时间
    guard let info = info else{
      dlog("没有可以扫描的数据")
      return
    }
    //扫描开始视频
    self.downloadMedia(forAD: info.startPicAD, withFileName: "stPic")
    self.downloadMedia(forAD: info.startVideoAD, withFileName: "stVideo")
    self.downloadMedia(forAD: info.pausePicAD, withFileName: "pausePic")
  }
  
  ///下载单个广告媒体
  func downloadMedia(forAD ad: SingleAD?, withFileName fileName: String){
    guard let ad = ad, let srcURL = ad.srcURL else { return } //检查
    if ad.fileName.isEmpty{
      var dstExt = ""
      if let ext = ad.srcURL?.pathExtension{
        dstExt = "." + ext
      }
      ad.fileName = fileName + dstExt //文件名
    }
    guard !ad.isDownloaded else { return } //检查没有下载
    let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
      return (ad.fileURL, [.removePreviousFile, .createIntermediateDirectories])
    }
    dlog("[下载]正在下载媒体文件:\(ad.fileName)")

    lessTimeOutAlamofire.download(srcURL, to: destination).responseData(completionHandler: { (ret) in
      DispatchQueue.global(qos: .background).async {
        guard ret.result.isSuccess else{
          dlog("[下载]拉取媒体文件失败!错误原因: ", ret.error?.localizedDescription ?? "无原因")
          return
        }
        dlog("[下载]成功拉取媒体文件", ad.fileName)
      }
    })
  }
  
  ///下载广告数据
  func downLoadAdData(){
    guard !self.isUsingNetWork else {
      return
    }
    ///使用网络中
    self.isUsingNetWork = true
    self.cleanAdData() //删掉旧的
    dlog("[下载广告]开始后台下载")
    lessTimeOutAlamofire.request(AdURL.adsURL).validate().responseJSON { (response) in
      guard response.result.isSuccess, let jsVal = response.value else{
        dlog("[下载广告][错误]服务器广告接口返回了无效空数据,本次放弃下载.")
        return
      }
      //TODO: 单独解析
      let json = JSON(jsVal)
      guard !json.isEmpty else{
        dlog("[下载广告][错误]服务器广告接口没有JSON格式数据,放弃下载.")
        return
      }
      self.isUsingNetWork = false
      self.readFromJson(json)
      self.saveAdData(json) //本地保存
    }
  }
  
  ///更新广告数据,传入本地数据
  func updateAdData(){
    dlog("检查服务器广告更新")
    guard let info = self.info else{
      dlog("本地没有广告,直接下载服务器广告.")
      self.downLoadAdData() //直接下载
      return
    }
    lessTimeOutAlamofire.request(AdURL.adinitURL).validate().responseJSON { (response) in
      guard let jsVal = response.value else{
        dlog("[更新检查]服务器初始化接口返回了空数据,本次放弃更新.")
        return
      }
      let updateTime = JSON(jsVal)["adUpdateTime"]
      if updateTime != JSON.null{
        dlog("读取到云端广告最后更新时间: ", updateTime)
        if updateTime.stringValue != info.lastAdUpdateTime{
          dlog("服务器广告有变化(\(info.lastAdUpdateTime) -> \(updateTime)),使用后台下载服务器广告.")
          self.downLoadAdData() //直接下载
        }else{
          dlog("本地广告数据和服务器一样!不必更新!")
          dlog("-----------------")
        }
      }
    }
  }
  
  
}

class ADInfo{
  /// 最后更新升级,同步服务器
  var lastAdUpdateTime: String = ""
  /// 片头广告的最小间隔时间,既两次中的差异
  var startAdshowTime: TimeInterval = 0
  
  /// 有开始广告
  var isHadStartAD: Bool{
    return startPicAD?.isDownloaded == true || startVideoAD?.isDownloaded == true
  }
  
  /// 有暂停广告
  var isHadPauseAD: Bool{
    return pausePicAD?.isDownloaded == true
  }
  
  /// 启动图片广告
  var startPicAD: SingleAD?
  
  /// 启动视频广告,必须是视频
  var startVideoAD: SingleAD?
  
  /// 暂停图片广告
  var pausePicAD: SingleAD?
}

//TODO: 生成最路径
/// 基本AD类
class SingleAD{
  /// 广告类型
  ///
  /// - video: 视频
  /// - pic: 图片
  enum SingleADType {
    case video
    case pic
  }
  
  /// [无用]对应json的wh,图片长*宽字符串
  var wh: String?
  /// [无用]对应服务器的图片ID,数字
  var adID: Int?
  /// [无用]对应json的间隔长度,当前未用吧
  var showTime: Int?
  /// 源下载地址
  var srcURL: URL?
  
  /// 文件名
  var fileName: String = ""
  
  ///是否有效-本地文件是否已经下载
  var isDownloaded : Bool{
    return FileManager.default.fileExists(atPath: fileURL.path)
  }
  
  ///文件实际地址
  var fileURL: URL!{
    return ADMan.workURL.appendingPathComponent(fileName)
  }
  
  /// 点击连接
  var clickLink: URL?
  /// 开启
  var enable = true
  /// 尺寸信息
  var size: CGSize?
  /// 长宽比,用以计算高度
  var ratio: CGFloat?{
    guard let size = size else {
      return nil
    }
    return size.width / size.height
  }
  /// 长度,秒数,图片代表倒计时,nil代表不存在,暂停图片
  var duartion: Int? = 0
  /// 广告类型
  var adType: SingleADType!
}

//等待废弃.

/// 视频开头广告
class StartVideoAD: SingleAD{
  override init(){
    super.init()
    self.fileName = "st.mp4"
    self.adType = .video
  }
}

/// 暂停图片广告
class PicAD: SingleAD{
  override init() {
    super.init()
    self.adType = .pic
  }
}


//MARK: 制造假数据
extension ADMan{
  ///假数据
  func makeFakeData(){
    dlog("制造虚构数据!但是有真实文件噢!")
    let info = ADInfo()
    info.lastAdUpdateTime = "1515837505"
    info.startAdshowTime = 3600
    
    let stAD = StartVideoAD()
    stAD.clickLink = URL(string: "https://shop176144336.taobao.com/")
    stAD.size = CGSize(width: 1280, height: 720)
    stAD.duartion = 10 //10秒?
    
    info.startVideoAD = stAD
    
    let pAD = PicAD()
    pAD.fileName = "zanting.png"
    pAD.clickLink = stAD.clickLink //地址
    pAD.size = CGSize(width: 1280, height: 720)
    
    info.pausePicAD = pAD
    
    self.info = info
    
    //拷贝文件
    dlog("写入本地广告文件")
    if let videoURL = Bundle.main.url(forResource: "piantou", withExtension: "mp4"){
      _ = try? FileManager.default.copyItem(at: videoURL, to: stAD.fileURL)
    }
    if let picURL = Bundle.main.url(forResource: "piantou", withExtension: "png"){
      _ = try? FileManager.default.copyItem(at: picURL, to: pAD.fileURL)
    }
  }
  
}
