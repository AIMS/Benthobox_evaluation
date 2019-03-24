import itertools
import scipy
import scikits.bootstrap as bootstrap
import pandas as pd
import numpy as np
import os.path as osp
import warnings
warnings.filterwarnings('ignore')
import plotly.plotly as py
import plotly.offline as pyo
import plotly.tools as tls
from plotly.offline import download_plotlyjs, init_notebook_mode, plot, iplot
init_notebook_mode(connected=True)
import matplotlib.pyplot as plt

import plotly.graph_objs as go
import sys
sys.path.append('/Users/uqmgonz1/Documents/GitHub/')

from Benthobox_evaluation.toolbox import beijbom_confmatrix as confmatrix




def F1plot(basedir,predfiles,obsfile, doplot=True):
    obs=pd.read_csv(osp.join(basedir,obsfile))
    results=[]
    CMList={}
    
    for pred in predfiles:
        #load results 
        pred=pd.read_csv(osp.join(basedir,pred))

        pred['FILENAME']=pred['Image'].str.split('/', expand=True)[4]
        pred['POINT_NO']=np.tile([1,2,3,4,5],int(len(pred['Image'])/5))
        pred=pred[['Experiment','FILENAME','POINT_NO', 'Prediction']]

        df=pd.merge(obs,pred)
        df=df.rename(index=str, columns={'KER_DESCRIPTION':'Obs', 'Prediction':'Pred'})
        df=df[['Experiment','SITE_NO','TRANSECT_NO','FILENAME','LAT','LNG','POINT_NO','Pred','Obs']]
        labels, levels = pd.factorize(pd.unique(df[['Obs','Pred']].values.ravel('K')))
        labelset=pd.DataFrame([labels,levels]).T
        labelset.columns=(['index','label'])
        df.Obs= df.Obs.replace(labelset.set_index('label')['index'])# ## Create confusion martix for the full labelset
        df.Pred= df.Pred.replace(labelset.set_index('label')['index'])# ## Create confusion martix for the full labelset
        cm = confmatrix.ConfMatrix(len(labelset.label), labelset = labelset.label)
        cm.add(df.Obs.astype(int), df.Pred.astype(int))
        #Get Accuracy and Coehn's kappa coefficient for all labels
        (acc, cok) = cm.get_accuracy()
        #Calculate F1 score for all labels
        recalls = cm.get_class_recalls()
        precisions = cm.get_class_precisions()
        f1s_denominator = precisions + recalls
        f1s_denominator[f1s_denominator == 0] = 1
        f1s = 2 * np.multiply(recalls, precisions) / f1s_denominator

        CMres=pd.DataFrame({
            'Experiment': df.Experiment[0],
            'Label':labelset.label,
            'F1s':f1s
        })
        results.append(CMres)
        CMList[df.Experiment[0]]=[]
        CMList[df.Experiment[0]].append(cm)
        
    results=pd.concat(results, axis=0)
    if doplot:
        data=[]
        for i in list(set(results['Experiment'])):
            dfs=results.loc[results['Experiment'] == i]
            a,k=CMList[i][0].get_accuracy()
            trace=go.Bar(
                x=dfs['Label'],
                y=dfs['F1s'],
        #         name=str(i))
                name="{0:s}, Acc.:{1:.2f}%, K.: {2:.2f}%".format(str(i),a*100,k*100))
            data.append(trace)

        layout = go.Layout(
            barmode='group',
            xaxis=dict(
                title='Labels',
                titlefont=dict(
                family='Courier New, monospace',
                size=18,
                color='#7f7f7f')),
            yaxis=dict(
                title='F1s',
                titlefont=dict(
                family='Courier New, monospace',
                size=18,
                color='#7f7f7f'))
        )

            

        fig = go.Figure(data=data, layout=layout)
        pyo.iplot(fig, filename='F1s per label')

    return results, CMList
