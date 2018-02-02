//
//  MainWindowController+AD.swift
//  RRPlayer
//
//  Created by SLboat on 2018/1/16.
//  Copyright © 2018年 lhc. All rights reserved.
//

import Foundation
import AVKit
import Cocoa

///没有空格和快捷键的按钮
class NoKeyEquivalentButton: NSButton{
  ///去掉快捷键
  override func performKeyEquivalent(with key: NSEvent) -> Bool {
    return true
  }
}

///点击图片
class ClickImageView: NSImageView{
  override func mouseDown(with event: NSEvent) {
    if let win = self.superview?.window?.windowController as? MainWindowController{
      dlog("[暂停广告]内部发生点击事件")
      win.adClick(self)
    }
  }
}

extension MainWindowController{
  /// 正在播放开始广告
  var isStartADPlaying:Bool {
    return startAdPlayLeftSec != nil
  }
  
  ///安装广告视图
  func setupAdView(){
    self.adPlayer.isHidden = true
    self.adJumpBtn.wantsLayer = true
    //播放停止的玩意
    NotificationCenter.default.addObserver(self, selector: #selector(donePlayerAD), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    
    //初始化按钮准备
    self.window!.initialFirstResponder = self.btnWaitSecState
  }
  
  ///卸载通知
  func uninstallAdView(){
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
  }
  
  ///显示视频启动广告
  func showStartAD(){
    self.hideAllAD()
    guard let adInfo = self.adMan.info, adInfo.isHadStartAD else{
      dlog("[启动广告][错误]没有广告可以显示,检查更新...")
      self.adMan.updateAdData()
      self.adMan.scanAndDownloadMedia()
      self.resumePlayForStartAD() //恢复
      return
    }
    guard self.adMan.isInfoFileExsit else {
      dlog("[启动广告][检查]本地数据库丢了,重新获取广告")
      //重新操作
      self.adMan.loadAdData()
      self.adMan.updateAdData()
      self.resumePlayForStartAD() //恢复
      return
    }
    /// 倒计时秒数
    var duartion = 10
    if let videoAD = adInfo.startVideoAD{
      self.closeVideoAD() //关闭,防止意外
      self.adPlayer.player = AVPlayer(url: videoAD.fileURL)
      self.syncVolumeForADPlayer() //初次同步音量
      self.adPlayer.isHidden = false
      self.adPlayer.player?.play()
      duartion = videoAD.duartion  ?? 20 //倒计时
      self.adLinkUrl = videoAD.clickLink
    }else if let picAD = adInfo.startPicAD, let image = NSImage(contentsOf: picAD.fileURL){
      self.adImage.image = image
      self.adImage.isHidden = false
      duartion = picAD.duartion  ?? 20 //倒计时
      self.adLinkUrl = picAD.clickLink
    }else{
      dlog("[启动广告][错误]广告数据异常,错误11,尝试请求重新获取媒体....")
      self.adMan.scanAndDownloadMedia() //检查
      return
    }
    
    //TODO: 倒计时准备
    self.btnWaitSecState.isHidden = false //留给别的去处理
    self.btnWaitSecState.title = "请稍等"
    self.adJumpBtn.isHidden = false
    self.setADTimer(duartion) //设置计时器
    self.enableControl = false //禁用
  }
  
  /// 暂停广告
  func showPauseAD(){
    guard !self.isStartADPlaying else { return }
    dlog("[暂停广告]准备显示...")
    self.hideAllAD()

    if let sliderCell = self.playSlider.cell as? PlaySliderCell{
      if sliderCell.isTracking{
        dlog("[暂停广告]正在拖动, 不必要显示!")
        return
      }
    }
    guard let adInfo = self.adMan.info, adInfo.isHadPauseAD else{
      dlog("[暂停广告]系统没有广告可以显示")
      return
    }
    if let picAD = adInfo.pausePicAD, let image = NSImage(contentsOf: picAD.fileURL){
      self.adImage.image = image
      self.adImage.isHidden = false
      self.adLinkUrl = picAD.clickLink
    }else{
      dlog("[暂停广告][错误]广告数据异常,应该请求重新获取....")
      return
    }
    self.adHideBtn.isHidden = false
  }
  
  /// 隐藏暂停广告
  func hidePauseAD(){
    guard !self.isStartADPlaying else { return }
    guard !self.adImage.isHidden else { //可能拖动来的,不理它
      return
    }
    self.hideAllAD()
  }

  //设置广告秒数剩余
  func setADTimer(_ sec: Int){
    if let timer = self.adTimer{ //处理时间
      timer.invalidate()
      self.adTimer = nil
    }
    guard sec > 0 else {
      dlog("[片头倒计时][错误]广告倒计时参数无效: ", sec)
      return
    }
    dlog("[片头倒计时]开始广告倒计时秒数: ", sec)
    self.startAdPlayLeftSec = sec //赋予时间
    //赋予计时器
    self.adTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(adTimerTick), userInfo: nil, repeats: true)
    self.btnWaitSecState.title = "将在 \(Int(sec)) 秒后开始播放"
  }
  
  ///同步显示广告剩余时间
  func showAdLeftSec(){
    guard let sec = self.startAdPlayLeftSec else {
      self.btnWaitSecState.title = "即将开始播放..."
      dlog("[显示]要求显示倒计时的数字异常")
      return
    }
    guard sec > 0 else {
      self.btnWaitSecState.title = "正在准备播放..."
      return
    }
    self.btnWaitSecState.title = "将在 \(Int(sec)) 秒后开始播放"
  }
  
  ///计时器呼叫
  @objc func adTimerTick(){
    guard let sec = self.startAdPlayLeftSec else{ //检查有效
      self.hideAllAD()
      dlog("[片头广告]倒计时丢失,可能是点击,不处理.")
      return
    }
    guard sec >= 0  else {
      dlog("[片头广告]广告倒计时结束了!")
      self.resumePlayForStartAD()
      return
    }
    self.startAdPlayLeftSec! -= 1 //减去1秒
    self.showAdLeftSec()
  }
  
  ///最初广告的开始播放
  func resumePlayForStartAD(){
    self.hideAllAD()
    self.adTimer?.invalidate()
    self.adTimer = nil
    self.startAdPlayLeftSec = nil
    //播放
    
    updatePlayButtonState(.on)
    player.togglePause(false)
  }
  
  ///隐藏所有广告玩意
  func hideAllAD(){
    self.enableControl = true //禁用
    self.closeVideoAD() //关闭
    self.adPlayer.isHidden = true
    self.adImage.isHidden = true
    self.adJumpBtn.isHidden = true
    self.btnWaitSecState.isHidden = true
    self.adHideBtn.isHidden = true
    self.adLinkUrl = nil //连接
    self.adTimer?.invalidate() //计时器也处理
    self.adTimer = nil
  }
  
  /// 关闭视频广告
  func closeVideoAD(){
    if let player = self.adPlayer.player{
      player.pause() //暂停
      player.cancelPendingPrerolls() //取消亲够
      player.currentItem?.cancelPendingSeeks()
      player.currentItem?.asset.cancelLoading()
    }
    self.adPlayer.player = nil
    self.adPlayer.isHidden = true
    self.startAdPlayLeftSec = nil //无效了
  }
  
  ///跳过开头广告
  @IBAction func jumpAD(_ sender: Any?){
    dlog("[片头广告]用户点击了跳过广告")
    self.resumePlayForStartAD()
    //开始播放?
  }
  
  ///隐藏暂停广告
  @IBAction func hideAD(_ sender: Any?){
    dlog("[暂停广告]用户点击了暂停广告")
    self.hidePauseAD()
    //开始播放?
  }
  
  ///工具: 获得文件大小比率
  func getVideoSize(forVideoURL url: URL) -> CGSize?{
    if let track = AVAsset(url: url).tracks(withMediaType: .video).first{ //载入
      let size = __CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform)
      return size
    }
    return nil
  }
  
  ///播放完毕
  @objc func donePlayerAD(){
    ///如果还在倒计时,等等
    if let sec = self.startAdPlayLeftSec, sec < 5 {
      dlog("[片头视频广告]倒计时即将结束,忽视播放完毕事件!")
      return
    }
    dlog("[片头视频广告]播放完毕事件!")
    self.hideAllAD() //关闭
  }
  
  ///广告点击
  @IBAction func adClick(_ sender: Any?){
    defer {
      //消失广告-暂停
      self.hideAllAD()
    }
    self.player.sendOSD(.playAfterAD)
    dlog("[互动]广告被用户点击了:-)")
    guard let url = self.adLinkUrl else {
      dlog("[互动][错误]没有点击的目的地址.")
      return
    }
    self.player.sendOSD(.clickedAD)
    NSWorkspace.shared.open(url)
  }
}
