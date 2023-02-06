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

    function size(Tree storage self) internal view returns (uint256 totalNodes) {
        TreeMetadata treeMetadata;
        ///@solidity memory-safe-assembly
        assembly {
            // self is a pointer to the first slot of the Tree struct, which contains treeMetadata
            treeMetadata := sload(self.slot)
        }
        return treeMetadata.totalNodes();
    }

    function getRoot(Tree storage self) internal view returns (uint256) {
        TreeMetadata rootMetadata;
        ///@solidity memory-safe-assembly
        assembly {
            rootMetadata := sload(self.slot)
        }
        // this is the key of the nodes mapping to be looked up
        uint256 key = rootMetadata.root();
        // declare so we can use outside of assembly
        Node rootNode;
        ///@solidity memory-safe-assembly
        assembly {
            // mapping storage slot is keccak(h(k) . p) where h(k) is padded key and p is slot of mapping
            mstore(0, key)
            // add 1 to tree slot to get mapping slot
            mstore(0x20, add(1, self.slot))
            rootNode := sload(keccak256(0, 0x40))
        }
        return rootNode.value();
    }

    function getKey(Tree storage self, uint256 value) internal view returns (uint32) {
        require(value != EMPTY, "value != EMPTY");
        mapping(uint256 => Node) storage nodes = self.nodes;
        uint256 probe = self.treeMetadata.root();
        while (probe != EMPTY) {
            Node probeNode = nodes[probe];
            uint256 probeValue = probeNode.value();

            if (value == probeValue) {
                return uint32(probe);
                // break;
            } else if (value < probeValue) {
                probe = probeNode.left();
            } else {
                probe = probeNode.right();
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
        mapping(uint256 => Node) storage nodes = self.nodes;
        Node keyNode = nodes[key];
        (, bool red, uint256 parent, uint256 left, uint256 right) = keyNode.unpack();
        return (value, nodes[parent].value(), nodes[left].value(), nodes[right].value(), red);
    }

    function getNodeByIndex(Tree storage self, uint256 key)
        internal
        view
        returns (uint256, uint256, uint256, uint256, bool)
    {
        // require(exists(self, value));
        require(key != EMPTY, string.concat("RBT::getNode()# NOT EXISTS ", uint2str(key)));
        // return(value, self.nodes[key].parent(), self.nodes[key].left(), self.nodes[key].right(), self.nodes[key].red());
        mapping(uint256 => Node) storage nodes = self.nodes;
        Node keyNode = nodes[key];
        (uint256 value, bool red, uint256 parent, uint256 left, uint256 right) = keyNode.unpack();

        return (value, nodes[parent].value(), nodes[left].value(), nodes[right].value(), red);
    }

    function exists(Tree storage self, uint256 value) internal view returns (bool) {
        return (value != EMPTY) && (getKey(self, value) != EMPTY);
        // return (value != EMPTY) && self.totalNodes != EMPTY ;
    }

    function rotateLeft(Tree storage self, uint32 key) private {
        mapping(uint256 => Node) storage nodes = self.nodes;
        Node keyNode = nodes[key];
        uint32 cursor = keyNode.right();
        Node cursorNode = nodes[cursor];
        uint32 keyParent = keyNode.parent();
        uint32 cursorLeft = cursorNode.left();
        keyNode = keyNode.setRight(cursorLeft);
        if (cursorLeft != EMPTY) {
            nodes[cursorLeft] = nodes[cursorLeft].setParent(key);
        }
        cursorNode = cursorNode.setParent(keyParent);
        if (keyParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(cursor);
        } else if (key == nodes[keyParent].left()) {
            nodes[keyParent] = nodes[keyParent].setLeft(cursor); //() = cursor;
        } else {
            nodes[keyParent] = nodes[keyParent].setRight(cursor); //) = cursor;
        }
        nodes[cursor] = cursorNode.setLeft(key);
        nodes[key] = keyNode.setParent(cursor);
    }

    function rotateRight(Tree storage self, uint32 key) private {
        mapping(uint256 => Node) storage nodes = self.nodes;
        Node keyNode = nodes[key];
        uint32 cursor = keyNode.left();
        Node cursorNode = nodes[cursor];
        uint32 keyParent = keyNode.parent();
        uint32 cursorRight = cursorNode.right();
        keyNode = keyNode.setLeft(cursorRight); // = cursorRight;
        if (cursorRight != EMPTY) {
            nodes[cursorRight] = nodes[cursorRight].setParent(key); //() = key;
        }
        cursorNode = cursorNode.setParent(keyParent); //() = keyParent;
        if (keyParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(cursor);
        } else if (key == nodes[keyParent].right()) {
            nodes[keyParent] = nodes[keyParent].setRight(cursor); //() = cursor;
        } else {
            nodes[keyParent] = nodes[keyParent].setLeft(cursor); //) = cursor;
        }
        nodes[cursor] = cursorNode.setRight(key); //) = key;
        nodes[key] = keyNode.setParent(cursor); //) = cursor;
    }

    function insertFixup(Tree storage self, uint32 key) private {
        mapping(uint256 => Node) storage nodes = self.nodes;
        Node keyNode = nodes[key];
        uint32 keyParent = keyNode.parent();

        uint32 cursor;
        while (key != self.treeMetadata.root() && nodes[keyParent].red()) {
            Node keyParentNode = nodes[keyParent];
            uint32 keyParentNodeParent = keyParentNode.parent();
            Node keyParentNodeParentNode = nodes[keyParentNodeParent];
            if (keyParent == keyParentNodeParentNode.left()) {
                cursor = keyParentNodeParentNode.right();
                if (nodes[cursor].red()) {
                    nodes[keyParent] = nodes[keyParent].setRed(false); //) = false;
                    nodes[cursor] = nodes[cursor].setRed(false); //) = false;
                    keyParentNodeParentNode = keyParentNodeParentNode.setRed(true);
                    nodes[keyParentNodeParent] = keyParentNodeParentNode;
                    key = keyParentNodeParent;
                } else {
                    if (key == keyParentNode.right()) {
                        key = keyParent;
                        rotateLeft(self, key);
                    }
                    keyParent = nodes[key].parent();
                    keyParentNode = nodes[keyParent].setRed(false);
                    nodes[keyParent] = keyParentNode; //.red() = false;
                    keyParentNodeParent = keyParentNode.parent();
                    keyParentNodeParentNode = nodes[keyParentNodeParent].setRed(true);
                    nodes[keyParentNodeParent] = keyParentNodeParentNode;
                    rotateRight(self, keyParentNodeParent);
                }
            } else {
                // if keyParent on right side
                cursor = keyParentNodeParentNode.left();
                if (nodes[cursor].red()) {
                    keyParentNode = keyParentNode.setRed(false);
                    nodes[keyParent] = keyParentNode; //) = false;
                    nodes[cursor] = nodes[cursor].setRed(false); //) = false;
                    nodes[keyParentNodeParent] = keyParentNodeParentNode.setRed(true); //) = true;
                    key = keyParentNodeParent;
                } else {
                    if (key == keyParentNode.left()) {
                        key = keyParent;
                        rotateRight(self, key);
                    }
                    keyParent = nodes[key].parent();
                    keyParentNode = nodes[keyParent].setRed(false);
                    nodes[keyParent] = nodes[keyParent].setRed(false); //) = false;
                    keyParentNodeParent = keyParentNode.parent();
                    nodes[keyParentNodeParent] = nodes[keyParentNodeParent].setRed(true); //) = true;
                    rotateLeft(self, keyParentNodeParent);
                }
            }
            keyNode = nodes[key];
            keyParent = keyNode.parent();
        }
        uint32 root = self.treeMetadata.root();
        nodes[root] = nodes[root].setRed(false); //) = false;
    }

    function insert(Tree storage self, uint160 value) internal {
        // console.log("inserting",value);
        require(value != EMPTY, "value != EMPTY");
        require(!exists(self, value), "No Duplicates! ");
        uint32 cursor = EMPTY;
        TreeMetadata treeMetadata = self.treeMetadata;
        uint32 probe = treeMetadata.root();
        // print(self);
        mapping(uint256 => Node) storage nodes = self.nodes;
        while (probe != EMPTY) {
            cursor = probe;
            Node probeNode = nodes[probe];
            if (value < probeNode.value()) {
                probe = probeNode.left();
            } else {
                probe = probeNode.right();
            }
        }
        // cursor = probe;
        uint32 newNodeIdx;
        unchecked {
            newNodeIdx = treeMetadata.totalNodes() + 1;
        }
        treeMetadata = treeMetadata.setTotalNodes(newNodeIdx);
        self.treeMetadata = treeMetadata;
        // console.log("newNodeIdx ",newNodeIdx);
        nodes[newNodeIdx] =
            NodeType.createNode({_value: value, _red: true, _parent: cursor, _left: EMPTY, _right: EMPTY});
        Node cursorNode = nodes[cursor];
        if (cursor == EMPTY) {
            self.treeMetadata = treeMetadata.setRoot(newNodeIdx);
        } else if (value < cursorNode.value()) {
            nodes[cursor] = cursorNode.setLeft(newNodeIdx); //) = newNodeIdx;
        } else {
            nodes[cursor] = cursorNode.setRight(newNodeIdx); //) = newNodeIdx;
        }
        // print(self);
        // console.log("insert ended",value);
        insertFixup(self, newNodeIdx);
    }

    function replaceParent(Tree storage self, uint32 a, uint32 b) private {
        mapping(uint256 => Node) storage nodes = self.nodes;
        uint32 bParent = nodes[b].parent();
        nodes[a] = nodes[a].setParent(bParent); //) = bParent;
        if (bParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(a);
        } else {
            Node bParentNode = nodes[bParent];
            if (b == bParentNode.left()) {
                nodes[bParent] = bParentNode.setLeft(a); // = a;
            } else {
                nodes[bParent] = bParentNode.setRight(a); // = a;
            }
        }
    }

    function removeFixup(Tree storage self, uint32 key) private {
        mapping(uint256 => Node) storage nodes = self.nodes;
        // console.log("removeFixup()#",key,self.nodes[key].value());
        uint32 cursor;
        while (key != self.treeMetadata.root() && !nodes[key].red()) {
            // console.log("removeFixup()# debug 1");
            Node keyNode = nodes[key];

            uint32 keyParent = keyNode.parent();
            Node keyParentNode = nodes[keyParent];
            if (key == keyParentNode.left()) {
                cursor = keyParentNode.right();
                Node cursorNode = nodes[cursor];
                if (cursorNode.red()) {
                    cursorNode = cursorNode.setRed(false);
                    nodes[cursor] = cursorNode; //) = false;
                    keyParentNode = keyParentNode.setRed(true); //) = true;
                    nodes[keyParent] = keyParentNode;
                    rotateLeft(self, keyParent);
                    // must reload keyparent after rotating
                    keyParentNode = nodes[keyParent];
                    cursor = keyParentNode.right();
                    cursorNode = nodes[cursor];
                }
                if (!nodes[cursorNode.left()].red() && !nodes[cursorNode.right()].red()) {
                    cursorNode = cursorNode.setRed(true); //) = true;
                    nodes[cursor] = cursorNode; //) = true;
                    key = keyParent;
                } else {
                    if (!nodes[cursorNode.right()].red()) {
                        nodes[cursorNode.left()] = nodes[cursorNode.left()].setRed(false); //) = false;
                        cursorNode = cursorNode.setRed(true); //) = true;
                        nodes[cursor] = cursorNode; //) = true;
                        rotateRight(self, cursor);
                        keyParentNode = nodes[keyParent];
                        cursor = keyParentNode.right();
                        cursorNode = nodes[cursor];
                    }
                    // reload in case it's been modified by rotating
                    // keyParentNode = nodes[keyParent];
                    cursorNode = cursorNode.setRed(keyParentNode.red());
                    nodes[cursor] = cursorNode;
                    keyParentNode = keyParentNode.setRed(false); //) = false;
                    nodes[keyParent] = keyParentNode; //) = false;
                    nodes[cursorNode.right()] = nodes[cursorNode.right()].setRed(false); //) = false;
                    rotateLeft(self, keyParent);
                    key = self.treeMetadata.root();
                }
            } else {
                cursor = nodes[keyParent].left();
                Node cursorNode = nodes[cursor];
                if (cursorNode.red()) {
                    cursorNode = cursorNode.setRed(false); //) = false;
                    nodes[cursor] = cursorNode; //) = false;
                    nodes[keyParent] = keyParentNode.setRed(true); //) = true;
                    rotateRight(self, keyParent);
                    keyParentNode = nodes[keyParent];
                    cursor = keyParentNode.left();
                    cursorNode = nodes[cursor];
                }
                if (!nodes[cursorNode.right()].red() && !nodes[cursorNode.left()].red()) {
                    cursorNode = cursorNode.setRed(true); //) = true;
                    nodes[cursor] = cursorNode; //) = true;
                    key = keyParent;
                } else {
                    if (!nodes[cursorNode.left()].red()) {
                        nodes[cursorNode.right()] = nodes[cursorNode.right()].setRed(false); //) = false;
                        cursorNode = cursorNode.setRed(true); //) = true;
                        nodes[cursor] = cursorNode.setRed(true); //) = true;
                        rotateLeft(self, cursor);
                        keyParentNode = nodes[keyParent];
                        cursor = keyParentNode.left();
                        cursorNode = nodes[cursor];
                    }
                    cursorNode = cursorNode.setRed(keyParentNode.red());
                    nodes[cursor] = cursorNode;
                    keyParentNode = keyParentNode.setRed(false); //) = false;
                    nodes[keyParent] = keyParentNode; //) = false;
                    nodes[cursorNode.left()] = nodes[cursorNode.left()].setRed(false); //) = false;
                    rotateRight(self, keyParent);
                    key = self.treeMetadata.root();
                }
            }
        }
        nodes[key] = nodes[key].setRed(false); //) = false;
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
