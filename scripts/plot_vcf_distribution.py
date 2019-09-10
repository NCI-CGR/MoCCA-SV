#!/usr/bin/env python3

import matplotlib
matplotlib.use('Agg')
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import vcf


parser = argparse.ArgumentParser(description='Generates histogram.')

parser.add_argument('inFile', help='Input file name')
parser.add_argument('headerNum', help='Row number of header in input file')
# note that this counts the first line as 0, not 1
parser.add_argument('plotMetric', help='Name of the column you want to plot')
# parser.add_argument('ylog', help='Y/N Y axis in log scale')
parser.add_argument('outFile', help='Name of output file')

myArgs = parser.parse_args()

myList=[]
with open('myArgs.inFile') as file:
    for record in vcf.Reader(file):
        if myArgs.plotMetric in record.FORMAT:
            myList.append(record.samples[1][myArgs.plotMetric]) # note that I think the [1] means the second sample column...need to find a way to do this by name in case order varies
myList=np.asarray(myList).astype(np.float)

plt.hist(myList, bins=20)
plt.title(myArgs.plotMetric + ' Distribution')
plt.xlabel(myArgs.plotMetric)
plt.ylabel('# SVs')
# if myArgs.ylog == 'y':
#     plt.yscale('log')
plt.savefig(myArgs.outFile)