//
//  Board.swift
//  ChineseChess
//
//  Created by Jiachen Ren on 11/17/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

class Board: Serializable {
    var matrix = [[Piece?]]()
    var history: History<Move>
    var curPlayer: Color
    
    // Since the initial layout in Chinese Chess is symmetrical in all quadrants,
    // we only need to specify the layout for one quadrant; the rest could be derived.
    static let initLayout: Dictionary<Pos, Identity> = [
        Pos(0, 0): .car,
        Pos(0, 1): .horse,
        Pos(0, 2): .elephant,
        Pos(0, 3): .guard,
        Pos(0, 4): .king,
        Pos(3, 4): .pawn,
        Pos(3, 0): .pawn,
        Pos(2, 1): .cannon,
        Pos(3, 2): .pawn
    ]
    
    // Stream available pieces
    var stream: [Piece] {
        return matrix.flatMap{$0}
            .filter{$0 != nil}
            .map{$0!}
    }
    
    init(other: Board) {
        matrix = other.matrix
        history = History(other.history)
        curPlayer = other.curPlayer
    }
    
    /// Load serialized game
    required convenience init(_ encoded: String) {
        self.init()
        
        // Load history in a new instance so that it won't interfere with current game state
        let history = History<Move>(encoded)
        
        // Replay history until latest game state
        history.stack.forEach {
            makeMove($0)
        }
    }
    
    init() {
        history = History<Move>()
        curPlayer = .red // Is the first player black or red?
        applyInitialLayout()
    }
    
    private func applyInitialLayout() {
        matrix = [[Piece?]](repeating: [Piece?](repeating: nil, count: 9), count: 10)
        
        // Apply symmetrical layout to all quadrants
        Board.initLayout.forEach { pair in
            let (pos, identity) = pair
            let blackPiece = identity.spawn(.black)
            let redPiece = identity.spawn(.red)
            
            set(pos, blackPiece) // Black LL
            set(pos.invertCol(), blackPiece.copy()) // Black LR
            
            let rPos = pos.invertRow()
            set(rPos, redPiece) // Red UL
            set(rPos.invertCol(), redPiece.copy()) // Right UR
        }
        
        // Assign position to each piece
        for r in 0..<matrix.count {
            for c in 0..<matrix[0].count {
                if let p = matrix[r][c] {
                    p.pos = Pos(r, c)
                }
            }
        }
    }
    
    /**
     - Note: Does not check if the move is a legal move, simply performs the move.
     - Parameters:
        - target: The position of the piece to be moved
        - dest: Where to put the designated piece.
     - Returns: The piece been eaten as a result of the move (if applicable)
     */
    @discardableResult
    func move(_ target: Pos, to dest: Pos, recordHistory: Bool = true) -> Piece? {
        guard let piece = matrix[target.row][target.col] else {
            return nil
        }
        set(target, nil)
        let eat = get(dest)
        set(dest, piece)
        curPlayer = curPlayer.next()
        
        if recordHistory {
            let mv = Move(target, dest, eat)
            history.push(mv)
        }
        
        return eat
    }
    
    func makeMove(_ move: Move) {
        self.move(move.origin, to: move.dest)
    }
    
    /**
     Redo last move
     */
    func redo() {
        if let mv = history.restore() {
            move(mv.origin, to: mv.dest, recordHistory: false)
        }
    }
    
    /**
     Undo last move
     */
    func undo() {
        if let mv = history.revert() {
            // Undo the move
            move(mv.dest, to: mv.origin, recordHistory: false)
            
            // Put the eaten piece back into its original position
            set(mv.dest, mv.eat)
        }
    }
    
    func set(_ pos: Pos, _ piece: Piece?) {
        matrix[pos.row][pos.col] = piece
        piece?.pos = pos
    }
    
    func get(_ pos: Pos) -> Piece? {
        return matrix[pos.row][pos.col]
    }
    
    func serialize() -> String {
        return history.serialize()
    }
}
