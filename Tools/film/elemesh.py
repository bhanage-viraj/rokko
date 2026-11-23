# ear + trunk bones inside the elephant head layer (fractions of the full 1024 frame): name, parent, pivot, end, radius, include box
MESH = {
 "ele_c": [("ear", None, (.545, .33), (.43, .50), .085, (0, 0, .555, 1)),
           ("trunk1", None, (.80, .52), (.84, .61), .05, (.76, .46, 1, 1)),
           ("trunk2", "trunk1", (.84, .61), (.91, .67), .05, (.80, .56, 1, 1))],
 "ele_d": [("ear", None, (.555, .34), (.45, .50), .085, (0, 0, .565, 1)),
           ("trunk1", None, (.75, .53), (.83, .60), .05, (.72, .47, 1, 1)),
           ("trunk2", "trunk1", (.83, .60), (.92, .645), .05, (.79, .55, 1, 1))],
}
