#!/usr/bin/env python3

# write a script that compares columns 1-4 to columns 5-8
    # if they're the same, (every single row should have one hit like this, since we're using the same bed file as input a and input b!)
    # if they're different, that's a legit self-overlap:
        # identify the outermost coordinates and use that to replace the overlapping SVs
        # how will this work with multiple overlapping SVs?  can I use the row number?
        # make a dict, with left side (file a) line numbers as keys, and chr, start, end as values
        # while line number = dict key, compare the start and ends - replace with outermost values
            # note that because of the previous step, every unique chr/start/end combo should be represented by a single line number only (e.g. not chr1 123 234 1, chr1 123 234 2)
            # if start > new start, start = new start
            # if end < new end, end = new end
            # actually, I won't have to check whether right and left are identical first, this should do it all....
                # chr1 123 234 1 chr1 123 234 -> ignored
                # chr1 123 234 1 chr1 123 236 -> chr1 123 236 2
                # chr1 123 234 1 chr1 125 237 -> chr1 123 237 3
        # now print out dict results - there should now be duplicate SVs (from e.g. above, lines 1, 2, and 3 will all be chr1 123 237)
        # finally, sort as I did earlier to remove dups

# input:
# chr1    1431000 1469000 71  chr1    1431000 1469000 71  38000
# chr1    1431000 1469000 71  chr1    1433000 1470000 72  36000
# chr1    1433000 1470000 72  chr1    1431000 1469000 71  36000
# chr1    1433000 1470000 72  chr1    1433000 1470000 72  37000
# chr1    2612000 2613000 73  chr1    2612000 2613000 73  1000
# chr1    2612800 2613700 74  chr1    2612800 2613700 74  900
# chr1    2621732 2626597 75  chr1    2621732 2626597 75  4865
# field #:
# 0       1       2       3   4       5       6       7   8
# dict:
# 0       1       2       key

# action per line:

# line 1:
    # {71:[chr1    1431000 1469000]}
# line 2:
    # {71:[chr1    1431000 1470000]}
# line 3:
    # {72:[chr1    1431000 1470000]}
# line 4:
    # {72:[chr1    1431000 1470000]}

import argparse

# handle command line arguments

parser = argparse.ArgumentParser(description='Takes bedtools intersect -wao output and reports the outermost breakends of the overlapping SVs.')
parser.add_argument('inFile', help='Input file name')
parser.add_argument('outFile', help='Output file name')
results = parser.parser_args()

svDict = {}
with open(results.inFile) as f:
    for line in f:
        fields = line.split()
        key, values = fields[3], fields[0:2]
        if key not in svDict:
            svDict[key] = values
        if int(svDict[key][1]) > int(field[5]):
            svDict[key][1] = field[5]
        if int(svDict[key][2]) < int(field[6]):
            svDict[key][2] = field[6]

with open(results.outFile) as out:
    for key, values in svDict.iteritems():
        out.write('%s\t%s\n' % (key, '\t'.join(values)))
