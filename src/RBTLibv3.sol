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
        mapping(uint256 => Node) storage nodes = self.nodes;
        Node keyNode = nodes[key];
        // console.log("removing ",value,key);
        Node cursorNode;
        if (keyNode.left() == EMPTY || keyNode.right() == EMPTY) {
            cursor = key;
            cursorNode = nodes[cursor];
        } else {
            cursor = keyNode.right();
            cursorNode = nodes[cursor];
            while (cursorNode.left() != EMPTY) {
                cursor = cursorNode.left(); // 13
                cursorNode = nodes[cursor];
            }
        }
        if (cursorNode.left() != EMPTY) {
            probe = cursorNode.left();
        } else {
            probe = cursorNode.right();
        }
        uint32 yParent = cursorNode.parent();
        nodes[probe] = nodes[probe].setParent(yParent); //) = yParent;
        // console.log("yParent,probe,cursor,key");
        // printNodeByIndex(self,yParent);
        // printNodeByIndex(self,probe);
        // printNodeByIndex(self,cursor);
        // printNodeByIndex(self,key);
        TreeMetadata treeMetadata = self.treeMetadata;
        if (yParent != EMPTY) {
            Node yParentNode = nodes[yParent];
            if (cursor == yParentNode.left()) {
                nodes[yParent] = yParentNode.setLeft(probe); //) = probe;
            } else {
                nodes[yParent] = yParentNode.setRight(probe); //) = probe;
            }
        } else {
            // console.log("debugg ```````````1");
            // replaceParent relies on self.treeMetadata being up to date
            treeMetadata = treeMetadata.setRoot(probe);
            self.treeMetadata = treeMetadata;
            // print(self);
        }
        bool doFixup = !nodes[cursor].red();
        if (cursor != key) {
            replaceParent(self, cursor, key);
            cursorNode = nodes[cursor].setLeft(nodes[key].left());
            cursorNode = cursorNode.setRight(nodes[key].right());
            uint256 cursorLeft = cursorNode.left();
            uint256 cursorRight = cursorNode.right();
            nodes[cursorLeft] = nodes[cursorLeft].setParent(cursor);
            nodes[cursorRight] = nodes[cursorRight].setParent(cursor);
            nodes[cursor] = cursorNode.setRed(nodes[key].red());
            (cursor, key) = (key, cursor);
            cursorNode = nodes[cursor];
        }
        if (doFixup) {
            // todo: can this modify cursor node?
            removeFixup(self, probe);
        }
        // refresh tree metadata
        treeMetadata = self.treeMetadata;
        // console.log("a4 doFixUp");
        // print(self);
        // console.log("cursor,self.totalNodes",cursor,self.totalNodes);
        uint32 last = treeMetadata.totalNodes();
        Node lastNode = nodes[last];
        if (nodes[cursor].value() != lastNode.value()) {
            nodes[cursor] = lastNode;
            uint32 lParent = lastNode.parent();
            Node lastParentNode = nodes[lParent];
            // printNodeByIndex(self,last);
            // console.log("lastNode",lastNode);
            // console.log("last.parent()",last.parent());
            // console.log("cursor",cursor);
            if (lastNode.parent() != EMPTY) {
                if (treeMetadata.totalNodes() == lastParentNode.left()) {
                    nodes[lParent] = lastParentNode.setLeft(cursor);
                } else {
                    nodes[lParent] = lastParentNode.setRight(cursor);
                }
            } else {
                treeMetadata = treeMetadata.setRoot(cursor);
            }
            if (lastNode.right() != EMPTY) {
                nodes[lastNode.right()] = nodes[lastNode.right()].setParent(cursor);
            }
            if (lastNode.left() != EMPTY) {
                nodes[lastNode.left()] = nodes[lastNode.left()].setParent(cursor);
            }
            // console.log("b4 delete");
            // print(self);
        }
        nodes[last] = Node.wrap(0);
        // console.log("self.totalNodes",self.totalNodes);
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
