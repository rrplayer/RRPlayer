//
//  RRModFlag.swift
//  iina
//
//  Created by SLboat on 2018/1/11.
//  Copyright © 2018年 lhc. All rights reserved.
//

import Foundation

/// 额外修改标志
class RRModFlag {
  /// 开启视频开头广告
  static let enableStartAD: Bool = true
  /// 禁止控制器和列表按钮-首页
  static let disableControllerAndPlistButton: Bool = true
  /// 禁止高级设置面板
  static let disableAdvancedConfigUI: Bool = true
  /// 禁止自动载入给播放列表
  static let disableAutoLoadAudioToPlayList: Bool = true
  
  /// 网络超时, 推荐25
  static let networkTIMEOUTSec:TimeInterval = 25.0
  /// [关闭][有其它优化]播放广告时禁止按钮-比如播放
  static let disableActionInAdPlaying: Bool = false
}
