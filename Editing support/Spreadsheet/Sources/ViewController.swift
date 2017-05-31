//
//  ViewController.swift
//  Spreadsheet
//
//  Created by Kishikawa Katsumi on 2017/06/01.
//  Copyright © 2017 Kishikawa Katsumi. All rights reserved.
//

import UIKit
import SpreadsheetView

class SelectionView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    func setup() {
        layer.borderColor = UIColor.blue.cgColor
        layer.borderWidth = 2
    }
}

class SpreadsheetViewEditorDataSource: SpreadsheetViewDataSource {
    var numberOfColumns = 7
    var numberOfRows = 22
    var mergedCells = [CellRange]()
    var mergedCellLayouts = [IndexPath: CellRange]()

    func numberOfColumns(in spreadsheetView: SpreadsheetView) -> Int {
        return numberOfColumns
    }

    func numberOfRows(in spreadsheetView: SpreadsheetView) -> Int {
        return numberOfRows
    }

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, widthForColumn column: Int) -> CGFloat {
        return 60
    }

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, heightForRow row: Int) -> CGFloat {
        return 30
    }

    func mergedCells(in spreadsheetView: SpreadsheetView) -> [CellRange] {
        return mergedCells
    }

    func mergeCells(cellRange: CellRange) {
        for column in cellRange.from.column...cellRange.to.column {
            for row in cellRange.from.row...cellRange.to.row {
                let indexPath = IndexPath(row: row, column: column)
                mergedCellLayouts[indexPath] = cellRange
            }
        }
        mergedCells.append(cellRange)
    }
}

class Spreadsheet: UIView, SpreadsheetViewDelegate {
    let spreadsheetView = SpreadsheetView()
    let dataSource = SpreadsheetViewEditorDataSource()

    let selectionView = SelectionView()
    var selectedRange: (from: IndexPath, to: IndexPath)?
    var selectedCellRange: CellRange?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    func setup() {
        spreadsheetView.frame = bounds
        spreadsheetView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        spreadsheetView.dataSource = dataSource
        spreadsheetView.delegate = self
        addSubview(spreadsheetView)

        selectionView.isHidden = true
        spreadsheetView.addSubview(selectionView)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan(gestureRecognizer:)))
        spreadsheetView.addGestureRecognizer(panGestureRecognizer)

        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressGestureRecognizer.minimumPressDuration = 0.25
        spreadsheetView.addGestureRecognizer(longPressGestureRecognizer)
    }

    func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            UIMenuController.shared.setMenuVisible(false, animated: true)

            spreadsheetView.isScrollEnabled = false
            let location = gestureRecognizer.location(in: spreadsheetView)
            if let indexPath = spreadsheetView.indexPathForItem(at: location) {
                selectedRange = (indexPath, indexPath)
                updateSelection(from: selectedRange!.from, to: selectedRange!.to)
                selectionView.isHidden = false
            }
        case .ended:
            spreadsheetView.isScrollEnabled = true

            becomeFirstResponder()
            let menuController = UIMenuController.shared
            menuController.menuItems = [UIMenuItem(title: "Cell Action...", action: #selector(cellAction(_:)))]
            menuController.setTargetRect(selectionView.frame, in: spreadsheetView)
            menuController.setMenuVisible(true, animated: true)
        default:
            let location = gestureRecognizer.location(in: spreadsheetView)
            if let indexPath = spreadsheetView.indexPathForItem(at: location), let range = selectedRange {
                selectedRange = (range.from, indexPath)
                selectedCellRange = normalizedCellRange(from: selectedRange!.from, to: selectedRange!.to)
                selectedCellRange = expandedCellRangeIfNecessary(cellRange: selectedCellRange!)
                let from = selectedCellRange!.from
                let to = selectedCellRange!.to
                updateSelection(from: IndexPath(row: from.row, column: from.column), to: IndexPath(row: to.row, column: to.column))
            }
        }
    }

    func pan(gestureRecognizer: UIPanGestureRecognizer) {
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }

    func cellAction(_ sender: Any?) {
        if let cellRange = selectedCellRange {
            mergeCells(cellRange: cellRange)
        }
    }

    func mergeCells(cellRange: CellRange) {
        dataSource.mergeCells(cellRange: cellRange)
        spreadsheetView.reloadData()
    }

    override func paste(_ sender: Any?) {

    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(paste(_:)) || action == #selector(cellAction(_:))
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    func normalizedCellRange(from: IndexPath, to: IndexPath) -> CellRange {
        if to.column < from.column && to.row < from.row {
            return CellRange(from: to, to: from)
        } else if to.column < from.column {
            return CellRange(from: IndexPath(row: from.row, column: to.column), to: IndexPath(row: to.row, column: from.column))
        } else  if to.row < from.row {
            return CellRange(from: IndexPath(row: to.row, column: from.column), to: IndexPath(row: from.row, column: to.column))
        } else {
            return CellRange(from: from, to: to)
        }
    }

    func expandedCellRangeIfNecessary(cellRange: CellRange) -> CellRange {
        var from = (row: cellRange.from.row, column: cellRange.from.column)
        var to = (row: cellRange.to.row, column: cellRange.to.column)
        for column in cellRange.from.column...cellRange.to.column {
            for row in cellRange.from.row...cellRange.to.row {
                if let mergedCell = dataSource.mergedCellLayouts[IndexPath(row: row, column: column)] {
                    if from.column > mergedCell.from.column {
                        from.column = mergedCell.from.column
                    }
                    if from.row > mergedCell.from.row {
                        from.row = mergedCell.from.row
                    }
                    if to.column < mergedCell.to.column {
                        to.column = mergedCell.to.column
                    }
                    if to.row < mergedCell.to.row {
                        to.row = mergedCell.to.row
                    }
                }
            }
        }
        return CellRange(from: from, to: to)
    }

    func updateSelection(from: IndexPath, to: IndexPath) {
        let fromRect = spreadsheetView.rectForItem(at: from)
        let toRect = spreadsheetView.rectForItem(at: to)
        selectionView.frame.origin = CGPoint(x: fromRect.origin.x, y: fromRect.origin.y)
        selectionView.frame.size = CGSize(width: toRect.maxX - fromRect.minX, height: toRect.maxY - fromRect.minY )
        selectionView.frame = selectionView.frame.insetBy(dx: -4, dy: -4)
    }

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, didSelectItemAt indexPath: IndexPath) {
        updateSelection(from: indexPath, to: indexPath)
        selectionView.isHidden = false
    }
}

class ViewController: UIViewController {
    let spreadsheet = Spreadsheet()

    override func viewDidLoad() {
        super.viewDidLoad()

        spreadsheet.frame = view.bounds
        spreadsheet.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(spreadsheet)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
