//
//  Player.swift
//  RemoTrack
//
//  Created by Ahmed Shokry on 12/29/16.
//  Copyright © 2016 Shockry. All rights reserved.
//

import Foundation

class Player: NSObject, NSCoding {
    
    //MARK: Properties
    
    var bestScore: UInt32
    
    
    //MARK: Types
    
    struct Keys {
        static let bestScore = "bestScore"
    }
    
    
    init(score: UInt32) {

        self.bestScore = score
    }
    
    //MARK: NSCoding
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(bestScore, forKey: Keys.bestScore)
    }
    
    
    required convenience init(coder aDecoder: NSCoder) {
        
        let playerScore = aDecoder.decodeObject(forKey: Keys.bestScore) as? UInt32 ?? 0
        self.init(score: UInt32(playerScore))
    }
    
    
    //MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("score", isDirectory:false)
    
}
