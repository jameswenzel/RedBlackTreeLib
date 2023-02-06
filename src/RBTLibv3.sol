// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {uint2str} from "./Utils.sol";
import {Node, NodeType} from "./lib/NodeType.sol";
import {TreeMetadata, TreeMetadataType} from "./lib/TreeMetadataType.sol";
import {console} from "forge-std/console.sol";

library RedBlackTreeLib {
    // using LibBitmap for Tree;

    uint32 private constant EMPTY = 0;

    struct Tree {
        TreeMetadata treeMetadata;
        mapping(uint256 => Node) nodes;
    }

    function size(Tree storage self) internal view returns (uint256) {
        return uint256(self.treeMetadata.totalNodes());
    }

    function getRoot(Tree storage self) internal view returns (uint256) {
        return self.nodes[self.treeMetadata.root()].value();
    }

    function getKey(Tree storage self, uint256 value) internal view returns (uint32) {
        require(value != EMPTY, "value != EMPTY");
        uint256 probe = self.treeMetadata.root();
        while (probe != EMPTY) {
            if (value == self.nodes[probe].value()) {
                return uint32(probe);
                // break;
            } else if (value < self.nodes[probe].value()) {
                probe = self.nodes[probe].left();
            } else {
                probe = self.nodes[probe].right();
            }
        }
        return uint32(probe);
    }

    function getNode(Tree storage self, uint256 value)
        internal
        view
        returns (uint256 _returnKey, uint256 _parent, uint256 _left, uint256 _right, bool _red)
    {
        // require(exists(self, value));
        uint32 key = getKey(self, value);
        require(key != EMPTY, string.concat("RBT::getNode()# NOT EXISTS ", uint2str(key)));
        // return(value, self.nodes[key].parent(), self.nodes[key].left(), self.nodes[key].right(), self.nodes[key].red());
        return (
            value,
            self.nodes[self.nodes[key].parent()].value(),
            self.nodes[self.nodes[key].left()].value(),
            self.nodes[self.nodes[key].right()].value(),
            self.nodes[key].red()
        );
    }

    function getNodeByIndex(Tree storage self, uint256 key)
        internal
        view
        returns (uint256 _returnKey, uint256 _parent, uint256 _left, uint256 _right, bool _red)
    {
        // require(exists(self, value));
        require(key != EMPTY, string.concat("RBT::getNode()# NOT EXISTS ", uint2str(key)));
        // return(value, self.nodes[key].parent(), self.nodes[key].left(), self.nodes[key].right(), self.nodes[key].red());
        return (
            self.nodes[key].value(),
            self.nodes[self.nodes[key].parent()].value(),
            self.nodes[self.nodes[key].left()].value(),
            self.nodes[self.nodes[key].right()].value(),
            self.nodes[key].red()
        );
    }

    function exists(Tree storage self, uint256 value) internal view returns (bool) {
        return (value != EMPTY) && (getKey(self, value) != EMPTY);
        // return (value != EMPTY) && self.totalNodes != EMPTY ;
    }

    function rotateLeft(Tree storage self, uint32 key) private {
        uint32 cursor = self.nodes[key].right();
        uint32 keyParent = self.nodes[key].parent();
        uint32 cursorLeft = self.nodes[cursor].left();
        self.nodes[key] = self.nodes[key].setRight(cursorLeft);
        if (cursorLeft != EMPTY) {
            self.nodes[cursorLeft] = self.nodes[cursorLeft].setParent(key);
        }
        self.nodes[cursor] = self.nodes[cursor].setParent(keyParent);
        if (keyParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(cursor);
        } else if (key == self.nodes[keyParent].left()) {
            self.nodes[keyParent] = self.nodes[keyParent].setLeft(cursor); //() = cursor;
        } else {
            self.nodes[keyParent] = self.nodes[keyParent].setRight(cursor); //) = cursor;
        }
        self.nodes[cursor] = self.nodes[cursor].setLeft(key);
        self.nodes[key] = self.nodes[key].setParent(cursor);
    }

    function rotateRight(Tree storage self, uint32 key) private {
        uint32 cursor = self.nodes[key].left();
        uint32 keyParent = self.nodes[key].parent();
        uint32 cursorRight = self.nodes[cursor].right();
        self.nodes[key] = self.nodes[key].setLeft(cursorRight); // = cursorRight;
        if (cursorRight != EMPTY) {
            self.nodes[cursorRight] = self.nodes[cursorRight].setParent(key); //() = key;
        }
        self.nodes[cursor] = self.nodes[cursor].setParent(keyParent); //() = keyParent;
        if (keyParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(cursor);
        } else if (key == self.nodes[keyParent].right()) {
            self.nodes[keyParent] = self.nodes[keyParent].setRight(cursor); //() = cursor;
        } else {
            self.nodes[keyParent] = self.nodes[keyParent].setLeft(cursor); //) = cursor;
        }
        self.nodes[cursor] = self.nodes[cursor].setRight(key); //) = key;
        self.nodes[key] = self.nodes[key].setParent(cursor); //) = cursor;
    }

    function insertFixup(Tree storage self, uint32 key) private {
        uint32 cursor;
        while (key != self.treeMetadata.root() && self.nodes[self.nodes[key].parent()].red()) {
            uint32 keyParent = self.nodes[key].parent();
            if (keyParent == self.nodes[self.nodes[keyParent].parent()].left()) {
                cursor = self.nodes[self.nodes[keyParent].parent()].right();
                if (self.nodes[cursor].red()) {
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(false); //) = false;
                    self.nodes[cursor] = self.nodes[cursor].setRed(false); //) = false;
                    self.nodes[self.nodes[keyParent].parent()] = self.nodes[self.nodes[keyParent].parent()].setRed(true); //) = true;
                    key = self.nodes[keyParent].parent();
                } else {
                    if (key == self.nodes[keyParent].right()) {
                        key = keyParent;
                        rotateLeft(self, key);
                    }
                    keyParent = self.nodes[key].parent();
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(false); //.red() = false;
                    self.nodes[self.nodes[keyParent].parent()] = self.nodes[self.nodes[keyParent].parent()].setRed(true); //) = true;
                    rotateRight(self, self.nodes[keyParent].parent());
                }
            } else {
                // if keyParent on right side
                cursor = self.nodes[self.nodes[keyParent].parent()].left();
                if (self.nodes[cursor].red()) {
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(false); //) = false;
                    self.nodes[cursor] = self.nodes[cursor].setRed(false); //) = false;
                    self.nodes[self.nodes[keyParent].parent()] = self.nodes[self.nodes[keyParent].parent()].setRed(true); //) = true;
                    key = self.nodes[keyParent].parent();
                } else {
                    if (key == self.nodes[keyParent].left()) {
                        key = keyParent;
                        rotateRight(self, key);
                    }
                    keyParent = self.nodes[key].parent();
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(false); //) = false;
                    self.nodes[self.nodes[keyParent].parent()] = self.nodes[self.nodes[keyParent].parent()].setRed(true); //) = true;
                    rotateLeft(self, self.nodes[keyParent].parent());
                }
            }
        }
        uint32 root = self.treeMetadata.root();
        self.nodes[root] = self.nodes[root].setRed(false); //) = false;
    }

    function insert(Tree storage self, uint160 value) internal {
        // console.log("inserting",value);
        require(value != EMPTY, "value != EMPTY");
        require(!exists(self, value), "No Duplicates! ");
        uint32 cursor = EMPTY;
        uint32 probe = self.treeMetadata.root();
        // print(self);

        while (probe != EMPTY) {
            cursor = probe;
            if (value < self.nodes[probe].value()) {
                probe = self.nodes[probe].left();
            } else {
                probe = self.nodes[probe].right();
            }
        }
        uint32 newNodeIdx = self.treeMetadata.totalNodes() + 1;
        self.treeMetadata = self.treeMetadata.setTotalNodes(newNodeIdx);

        // console.log("newNodeIdx ",newNodeIdx);
        self.nodes[newNodeIdx] =
            NodeType.createNode({_value: value, _red: true, _parent: cursor, _left: EMPTY, _right: EMPTY});
        if (cursor == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(newNodeIdx);
        } else if (value < self.nodes[cursor].value()) {
            self.nodes[cursor] = self.nodes[cursor].setLeft(newNodeIdx); //) = newNodeIdx;
        } else {
            self.nodes[cursor] = self.nodes[cursor].setRight(newNodeIdx); //) = newNodeIdx;
        }
        // print(self);
        // console.log("insert ended",value);
        insertFixup(self, newNodeIdx);
    }

    function replaceParent(Tree storage self, uint32 a, uint32 b) private {
        uint32 bParent = self.nodes[b].parent();
        self.nodes[a] = self.nodes[a].setParent(bParent); //) = bParent;
        if (bParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(a);
        } else {
            if (b == self.nodes[bParent].left()) {
                self.nodes[bParent] = self.nodes[bParent].setLeft(a); // = a;
            } else {
                self.nodes[bParent] = self.nodes[bParent].setRight(a); // = a;
            }
        }
    }

    function removeFixup(Tree storage self, uint32 key) private {
        // console.log("removeFixup()#",key,self.nodes[key].value());
        uint32 cursor;
        while (key != self.treeMetadata.root() && !self.nodes[key].red()) {
            // console.log("removeFixup()# debug 1");

            uint32 keyParent = self.nodes[key].parent();
            if (key == self.nodes[keyParent].left()) {
                cursor = self.nodes[keyParent].right();
                if (self.nodes[cursor].red()) {
                    self.nodes[cursor] = self.nodes[cursor].setRed(false); //) = false;
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(true); //) = true;
                    rotateLeft(self, keyParent);
                    cursor = self.nodes[keyParent].right();
                }
                if (!self.nodes[self.nodes[cursor].left()].red() && !self.nodes[self.nodes[cursor].right()].red()) {
                    self.nodes[cursor] = self.nodes[cursor].setRed(true); //) = true;
                    key = keyParent;
                } else {
                    if (!self.nodes[self.nodes[cursor].right()].red()) {
                        self.nodes[self.nodes[cursor].left()] = self.nodes[self.nodes[cursor].left()].setRed(false); //) = false;
                        self.nodes[cursor] = self.nodes[cursor].setRed(true); //) = true;
                        rotateRight(self, cursor);
                        cursor = self.nodes[keyParent].right();
                    }
                    self.nodes[cursor] = self.nodes[cursor].setRed(self.nodes[keyParent].red());
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(false); //) = false;
                    self.nodes[self.nodes[cursor].right()] = self.nodes[self.nodes[cursor].right()].setRed(false); //) = false;
                    rotateLeft(self, keyParent);
                    key = self.treeMetadata.root();
                }
            } else {
                cursor = self.nodes[keyParent].left();
                if (self.nodes[cursor].red()) {
                    self.nodes[cursor] = self.nodes[cursor].setRed(false); //) = false;
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(true); //) = true;
                    rotateRight(self, keyParent);
                    cursor = self.nodes[keyParent].left();
                }
                if (!self.nodes[self.nodes[cursor].right()].red() && !self.nodes[self.nodes[cursor].left()].red()) {
                    self.nodes[cursor] = self.nodes[cursor].setRed(true); //) = true;
                    key = keyParent;
                } else {
                    if (!self.nodes[self.nodes[cursor].left()].red()) {
                        self.nodes[self.nodes[cursor].right()] = self.nodes[self.nodes[cursor].right()].setRed(false); //) = false;
                        self.nodes[cursor] = self.nodes[cursor].setRed(true); //) = true;
                        rotateLeft(self, cursor);
                        cursor = self.nodes[keyParent].left();
                    }
                    self.nodes[cursor] = self.nodes[cursor].setRed(self.nodes[keyParent].red());
                    self.nodes[keyParent] = self.nodes[keyParent].setRed(false); //) = false;
                    self.nodes[self.nodes[cursor].left()] = self.nodes[self.nodes[cursor].left()].setRed(false); //) = false;
                    rotateRight(self, keyParent);
                    key = self.treeMetadata.root();
                }
            }
        }
        self.nodes[key] = self.nodes[key].setRed(false); //) = false;
    }

    function remove(Tree storage self, uint256 value) internal {
        require(value != EMPTY);
        // require(exists(self, value));
        uint32 probe;
        uint32 cursor;
        uint32 key = getKey(self, value);
        // console.log("removing ",value,key);
        if (self.nodes[key].left() == EMPTY || self.nodes[key].right() == EMPTY) {
            cursor = key;
        } else {
            cursor = self.nodes[key].right();
            while (self.nodes[cursor].left() != EMPTY) {
                cursor = self.nodes[cursor].left(); // 13
            }
            // cursor = self.nodes[key].left();
            // while (self.nodes[cursor].right() != EMPTY) {
            //     cursor = self.nodes[cursor].right(); // 13
            // }
        }
        if (self.nodes[cursor].left() != EMPTY) {
            probe = self.nodes[cursor].left();
        } else {
            probe = self.nodes[cursor].right();
        }
        uint32 yParent = self.nodes[cursor].parent();
        self.nodes[probe] = self.nodes[probe].setParent(yParent); //) = yParent;
        // console.log("yParent,probe,cursor,key");
        // printNodeByIndex(self,yParent);
        // printNodeByIndex(self,probe);
        // printNodeByIndex(self,cursor);
        // printNodeByIndex(self,key);
        if (yParent != EMPTY) {
            if (cursor == self.nodes[yParent].left()) {
                self.nodes[yParent] = self.nodes[yParent].setLeft(probe); //) = probe;
            } else {
                self.nodes[yParent] = self.nodes[yParent].setRight(probe); //) = probe;
            }
        } else {
            // console.log("debugg ```````````1");
            self.treeMetadata = self.treeMetadata.setRoot(probe);
            // print(self);
        }
        bool doFixup = !self.nodes[cursor].red();
        if (cursor != key) {
            replaceParent(self, cursor, key);
            self.nodes[cursor] = self.nodes[cursor].setLeft(self.nodes[key].left());
            self.nodes[self.nodes[cursor].left()] = self.nodes[self.nodes[cursor].left()].setParent(cursor);
            self.nodes[cursor] = self.nodes[cursor].setRight(self.nodes[key].right());
            self.nodes[self.nodes[cursor].right()] = self.nodes[self.nodes[cursor].right()].setParent(cursor);
            self.nodes[cursor] = self.nodes[cursor].setRed(self.nodes[key].red());
            (cursor, key) = (key, cursor);
        }
        if (doFixup) {
            removeFixup(self, probe);
        }
        // console.log("a4 doFixUp");
        // print(self);
        // console.log("cursor,self.totalNodes",cursor,self.totalNodes);
        uint32 last = self.treeMetadata.totalNodes();
        Node lastNode = self.nodes[last];
        if (self.nodes[cursor].value() != lastNode.value()) {
            self.nodes[cursor] = lastNode;
            uint32 lParent = lastNode.parent();
            // printNodeByIndex(self,last);
            // console.log("lastNode",lastNode);
            // console.log("last.parent()",last.parent());
            // console.log("cursor",cursor);
            if (lastNode.parent() != EMPTY) {
                if (self.treeMetadata.totalNodes() == self.nodes[lParent].left()) {
                    self.nodes[lParent] = self.nodes[lParent].setLeft(cursor);
                } else {
                    self.nodes[lParent] = self.nodes[lParent].setRight(cursor);
                }
            } else {
                self.treeMetadata = self.treeMetadata.setRoot(cursor);
            }
            if (lastNode.right() != EMPTY) {
                self.nodes[lastNode.right()] = self.nodes[lastNode.right()].setParent(cursor);
            }
            if (lastNode.left() != EMPTY) {
                self.nodes[lastNode.left()] = self.nodes[lastNode.left()].setParent(cursor);
            }
            // console.log("b4 delete");
            // print(self);
        }
        self.nodes[last] = Node.wrap(0);
        // console.log("self.totalNodes",self.totalNodes);
        TreeMetadata treeMetadata = self.treeMetadata;
        self.treeMetadata = treeMetadata.setTotalNodes(treeMetadata.totalNodes() - 1);
    }

    function print(Tree storage self) internal view {
        console.log("--------- root", self.treeMetadata.root(), " totalNodes", self.treeMetadata.totalNodes());
        uint256 _size = self.treeMetadata.totalNodes();
        for (uint256 key; key <= _size; key++) {
            console.log(
                string.concat(
                    uint2str(key),
                    " ",
                    self.nodes[key].red() ? "R" : "B",
                    " ",
                    uint2str(self.nodes[key].parent()),
                    " ",
                    uint2str(self.nodes[key].left()),
                    " ",
                    uint2str(self.nodes[key].right()),
                    " ",
                    uint2str(self.nodes[key].value()),
                    " "
                )
            );
        }
        console.log("------------------");
    }

    function printNodeByIndex(Tree storage self, uint256 key) internal view {
        console.log(
            string.concat(
                uint2str(key),
                " ",
                self.nodes[key].red() ? "R" : "B",
                " ",
                uint2str(self.nodes[key].parent()),
                " ",
                uint2str(self.nodes[key].left()),
                " ",
                uint2str(self.nodes[key].right()),
                " ",
                uint2str(self.nodes[key].value()),
                " "
            )
        );
    }

    function printNode(Tree storage self, uint256 val) internal view {
        uint256 key = getKey(self, val);
        console.log(
            string.concat(
                uint2str(key),
                " ",
                self.nodes[key].red() ? "R" : "B",
                " ",
                uint2str(self.nodes[key].parent()),
                " ",
                uint2str(self.nodes[key].left()),
                " ",
                uint2str(self.nodes[key].right()),
                " ",
                uint2str(self.nodes[key].value()),
                " "
            )
        );
    }
}
