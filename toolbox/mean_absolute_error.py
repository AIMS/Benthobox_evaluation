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

def flatten_aggregated_dataframe(
    gdf, concat_name=True, concat_separator=' ', name_level=1, inplace=False):
    """
    Flatten aggregated DataFrame.

    Args:
        gdf: DataFrame obtained through aggregation.
        concat_name: Whether to concatenate original column name and
            aggregation function name in the case of MultiIndex columns.
        concat_separator: Which string to place between original column name
            and aggregation function name if concat_name is True.
        name_level: Which element of a column tuple to use in the case of 
            MultiIndex columns and concat_name == False. Should be 0 for 
            original column name and 1 for aggregation function name.
        inplace: Whether to modify the aggregated DataFrame directly 
            (or return a copy).
    """
    if not inplace:
        gdf = gdf.copy()
    if type(gdf.columns) == pd.core.index.MultiIndex:
        if concat_name:
            columns = [concat_separator.join(col) for col in gdf.columns]
        else:
            columns = [col[name_level % 2] for col in gdf.columns]
        gdf.columns = columns
    return gdf.reset_index()

def MAEplot(basedir,predfiles,obsfile, doplot=True):
    obs=pd.read_csv(osp.join(basedir,obsfile))
    results=[]
    
    for pred in predfiles:
    #load results 
        pred=pd.read_csv(osp.join(basedir,pred))

        pred['FILENAME']=pred['Image'].str.split('/', expand=True)[4]
        pred['POINT_NO']=np.tile([1,2,3,4,5],int(len(pred['Image'])/5))
        pred=pred[['Experiment','FILENAME','POINT_NO', 'Prediction']]

        df=pd.merge(obs,pred)
        df=df.rename(index=str, columns={'KER_DESCRIPTION':'Obs', 'Prediction':'Pred'})
        df=df[['Experiment','SITE_NO','TRANSECT_NO','FILENAME','LAT','LNG','POINT_NO','Pred','Obs']]
        df=pd.melt(df, id_vars=['Experiment','SITE_NO','TRANSECT_NO','FILENAME','LAT','LNG','POINT_NO'], 
               value_vars=['Obs','Pred'],
               var_name='method', value_name='label').reset_index()

        # df=df.dropna()
        df=df.groupby(['Experiment','SITE_NO','TRANSECT_NO',
                            'FILENAME','LAT','LNG','method','label']).size().reset_index(name="count")
        df=flatten_aggregated_dataframe(df)
        df=df.groupby(['Experiment','SITE_NO','TRANSECT_NO','LAT','LNG','method','label']).agg({'count': 'sum'})
        df=df.groupby(level=['Experiment','SITE_NO',
                             'TRANSECT_NO','LAT','LNG','method']).apply(lambda x: 100 * x / float(x.sum())).reset_index()

        df=df.pivot_table(index=['Experiment','SITE_NO','TRANSECT_NO','LAT','LNG','label'], columns='method',
                      values='count').reset_index().fillna(value=0)
        df['error']=abs(df['Obs']-df['Pred'])
        df=df.groupby(['Experiment','label'])['error'].agg({'mean': np.mean, 
                                     'std': np.std, 
                                     'cilow': lambda x: bootstrap.ci(x, statfunction=scipy.mean)[0],
                                     'cimax':lambda x: bootstrap.ci(x, statfunction=scipy.mean)[1],
                                   }).reset_index()
        results.append(df)
        
        
    results=pd.concat(results, axis=0)
    results[['cilow',"cimax"]]=results[['cilow',"cimax"]].astype('float')
    results['cilow']=results['mean']-results['cilow']
    results['cimax']=results['cimax']-results['mean']

    if doplot:
        data=[]
        for i in list(set(results['Experiment'])):
            df=results.loc[results['Experiment'] == i]
            trace=go.Bar(
                x=df['label'],
                y=df['mean'],
                name=str(i),
                error_y=dict(
                        type='data',
                        symmetric=False,
                        array=df['cimax'],
                        arrayminus=df['cilow']))
            data.append(trace)

        layout = go.Layout(
            barmode='group'
        )

        fig = go.Figure(data=data, layout=layout)
        pyo.iplot(fig, filename='error-bar-bar')

    return results