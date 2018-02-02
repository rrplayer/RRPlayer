//
//  OverUserDefaults.swift
//  iina
//
//  Created by SLboat on 2018/1/7.
//  Copyright © 2018年 lhc. All rights reserved.
//

import Cocoa

/// 出于这样的原因,覆盖一些用户设置
class OverUserDefaults {
  /// 重置设置
  static func resetUD(){
    typealias pm = Preference
    pm.set(pm.ActionAfterLaunch.welcomeWindow.rawValue, for: .actionAfterLaunch) //不要欢迎窗口
    pm.set(false, for: .alwaysOpenInNewWindow) //不要总是打开新窗口
    pm.set(true, for: .quitWhenNoOpenedWindow) //最后窗口离开退出
    //高级设置
    pm.set(false, for: .enableAdvancedSettings) //高级玩意不要
  
    //youtube不要
    pm.set(false, for: .ytdlEnabled)
    
    //左右功能
    pm.set(pm.ArrowButtonAction.playlist.rawValue, for: .arrowButtonAction)
    
    //配置当前设置文件
    pm.set("IINA Default", for: .currentInputConfigName)
    
    
    /* 暂无启用 */
    //底部样式
    //pm.set(pm.OSCPosition.bottom.rawValue, for: .oscPosition) //底部的osd播放
    
    //去掉恢复
    //pm.set(false, for: .resumeLastPosition) //不恢复最后的播放
    
    //历史记录关闭
    //pm.set(false, for: .recordPlaybackHistory)
    //pm.set(false, for: .recordRecentFiles)
    //pm.set(false, for: .trackAllFilesInRecentOpenMenu)
    
    //其它的-可考虑释放??
    //pm.set(pm.ScrollAction.volume.rawValue, for: .verticalScrollAction)
    //pm.set(pm.ScrollAction.none.rawValue, for: .horizontalScrollAction)
  }
}
