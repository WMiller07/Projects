#!/usr/bin/env python
# coding: utf-8

# In[1]:


import pyodbc
import numpy as np
import pandas as pd


# In[2]:


sql_driver = 'DRIVER={ODBC Driver 13 for SQL Server};'
sql_server = 'SERVER=sage;'
sql_db = 'DATABASE=BUYS;'
sql_UID = 'Trusted_Connection=yes;'

cnxn = pyodbc.connect(sql_driver + sql_server + sql_db + sql_UID)


# In[13]:


def load_QueryFromFile(fn):
    f = open(fn, 'r')
    return f.read()

def fetch_Data(fn, cnxn):
    q = load_QueryFromFile(fn)
    df = pd.read_sql(sql=q, con=cnxn)
    return df


# In[10]:


f = load_QueryFromFile('./query/actual_FromNRF2017Week1.sql')


# In[14]:


df = fetch_Data('./query/actual_FromNRF2017Week1.sql', cnxn)


# In[15]:


df


# In[ ]:




