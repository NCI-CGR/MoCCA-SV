#!/usr/bin/env python3

import matplotlib
matplotlib.use('Agg')
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
#import seaborn as sns



parser = argparse.ArgumentParser(description='Generates histogram.')

parser.add_argument('inFile', help='Input file name')
parser.add_argument('headerNum', help='Row number of header in input file')
# note that this counts the first line as 0, not 1
parser.add_argument('plotMetric', help='Name of the column you want to plot')
# parser.add_argument('ylog', help='Y/N Y axis in log scale')
parser.add_argument('outFile', help='Name of output file')

myArgs = parser.parse_args()

df = pd.read_table(myArgs.inFile, header=int(myArgs.headerNum))
#print(df)
#df
#sns.set_style("white")
plt.hist(df[myArgs.plotMetric], bins=20)
plt.title(myArgs.plotMetric + ' Distribution')
plt.xlabel(myArgs.plotMetric)
plt.ylabel('# SVs')
# if myArgs.ylog == 'y':
#     plt.yscale('log')
plt.savefig(myArgs.outFile)