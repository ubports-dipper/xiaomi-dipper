/*
 * Copyright (C) 2014 Canonical Ltd.
 * Copyright (C) 2020-2026 UBports Foundation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.15
import Lomiri.Components 1.3
import "../../../Components"

Item {
    id: root
    property alias expanded: row.expanded
    property alias finishedExpanding: row.finishedExpanding
    property alias interactive: row.interactive
    property alias model: row.model
    property alias unitProgress: row.unitProgress
    property alias enableLateralChanges: row.enableLateralChanges
    property alias overFlowWidth: row.overFlowWidth
    readonly property alias currentItemIndex: row.currentItemIndex
    property real lateralPosition: -1
    property int alignment: Qt.AlignRight
    readonly property int rowContentX: row.contentX
    property alias screenIndex: row.screenIndex
    property alias orientation: row.screenOrientation

    property alias hideRow: row.hideRow
    property alias rowItemDelegate: row.delegate

    // Dipper: display cutouts only apply in portrait, so in landscape the
    // 96 px rounded screen corners clip the first/last panel items (the clock).
    // Keep the row clear of them on the built-in screen. 40 px is how far the
    // corner reaches in at the top of the text on the gu(3) panel.
    readonly property real landscapeCornerInset:
        screenIndex === 0 && (orientation === Qt.LandscapeOrientation
                              || orientation === Qt.InvertedLandscapeOrientation) ? 40 : 0

    implicitWidth: row.contentWidth

    function selectItemAt(lateralPosition) {
        if (!expanded) {
            row.resetCurrentItem();
        }
        var mapped = root.mapToItem(row, lateralPosition, 0);
        row.selectItemAt(mapped.x);
    }

    function selectPreviousItem() {
        if (!expanded) {
            row.resetCurrentItem();
        }
        row.selectPreviousItem();
    }

    function selectNextItem() {
        if (!expanded) {
            row.resetCurrentItem();
        }
        row.selectNextItem();
    }

    function setCurrentItemIndex(index) {
        if (!expanded) {
            row.resetCurrentItem();
        }
        row.setCurrentItemIndex(index);
    }

    function addScrollOffset(scrollAmount) {
        if (root.alignment == Qt.AlignLeft) {
            scrollAmount = -scrollAmount;
        }
        // If we are scrolling left and we are already on the first item, stop if the item is fully on screen
        // this is necessary because of a hack in PanelItemRow (adds extra space to row.contentWidth)
        if (scrollAmount < 0 && row.currentItemIndex === 0 && row.currentItem.mapToItem(root, 0, 0).x > 0) {
            return;
        }
        row.contentX = Math.min(Math.max(row.contentX - scrollAmount, 0), row.contentWidth);
        root.lateralPositionChanged();
    }

    Item {
        id: rowContainer
        anchors.fill: parent
        anchors.leftMargin: root.landscapeCornerInset
        anchors.rightMargin: root.landscapeCornerInset
        clip: expanded || row.width > rowContainer.width

        PanelItemRow {
            id: row
            objectName: "panelItemRow"
            anchors.fill: parent

            lateralPosition: {
                if (root.lateralPosition == -1) return -1;

                var mapped = root.mapToItem(row, root.lateralPosition, 0);
                return Math.min(Math.max(mapped.x, 0), row.width);
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.expanded
                propagateComposedEvents: true
                onClicked: {
                    row.selectItemAt(mouse.x);
                    mouse.accepted = false;
                }
                onPressed: {
                    row.selectItemAt(mouse.x);
                    mouse.accepted = false;
                }
            }
        }
    }
}
