/***************************************************************************
 *                                                                         *
 *  matrix.h
 *
 *   
 *
 *                                                                         *
 ***************************************************************************/
#ifndef __ARRAY__
#define __ARRAY__

using namespace std;
/***************************************************************************
 *                                                                         *
 *  markov.h
 *  Markov chain
 *    
 *  
 *
 *                                                                         *
 ***************************************************************************/
#ifndef __MARKOV__
#define __MARKOV__

using namespace std;

#include <fstream>
#include <iostream> 
#include <vector>
#include <algorithm>
#include <string>
#include <cmath>

#include "utils.h"

#define ALPHABET_SIZE 4
#define ALPHABET "ACGT"

struct Markov
{
/*
    Stationnary
    Maximum Likelihood parameters estimation with pseudo count:
    
                       C(suffix|prefix) + pseudo
    P(suffix|prefix) = -------------------------
                         C(prefix) + N pseudo 

    N: number of suffixes
    P(suffix|prefix) (example P(C|AA))
    C(suffix|prefix): prefix-suffix count (example AAC)
    C(prefix): prefix count (example AA)

*/

    int order;
    double pseudo;     // pseudo-count (used for smoothing)
    double **T;        // transition matrix
    double *S;         // stationary vector
    int msize;         // transition matrix size (number of rows)
    double *priori;    // priori vector (pA, pC, pG, pT)
    double *logpriori; // log priori vector (pA, pC, pG, pT)

    int alphabet_size;
    
    double p;
    int prefix;
    int suffix;
    int idx;
    
    Markov(int o=-1, double p=1.0)
    {
        order = o;
        alphabet_size = ALPHABET_SIZE;
        T = NULL;
        S = NULL;
        priori = NULL;
        logpriori = NULL;
        if (order >= 0)
            alloc(o, p);
    }
    
    void alloc(int o, double p=1.0)
    {
        pseudo = 1.0;
        order = o;
        msize = (int) pow((double) ALPHABET_SIZE, order);
        priori = new double[ALPHABET_SIZE];
        logpriori = new double[ALPHABET_SIZE];

        S = new double[msize];
        T = new double*[msize];
        for (int i = 0; i < msize; i++)
            T[i] = new double[ALPHABET_SIZE];

        // init values
        for (int i = 0; i < msize; i++)
        {
            S[i] = 1.0;
            for (int j = 0; j < ALPHABET_SIZE; j++)
                T[i][j] = 0.0;
        }
    }

    void dealloc()
    {
        if (order != -1)
        {
            delete []priori;
            delete []logpriori;
             for (int i = 0; i < msize; i++)
                delete []T[i];
            delete []T;
            delete []S;     
        }
    }

    ~Markov() 
    {
        dealloc();
    }

    Markov(const Markov& m)
    {
        order = m.order;
        pseudo = m.pseudo;
        msize = m.msize;
        alloc(order, pseudo);

        //copy values
        for (int i = 0; i < msize; i++)
        {
            S[i] = m.S[i];
            for (int j = 0; j < ALPHABET_SIZE; j++)
                T[i][j] = m.T[i][j];
        }
        for (int j = 0; j < ALPHABET_SIZE; j++)
        {
            priori[j] = m.priori[j];
            logpriori[j] = m.logpriori[j];

        }
    }

    int word2index(char *word, int len)
    {
        idx = 0;
        int P = 1;
        for (int i = 0; i < len; i++)
        {
            idx += (int) word[len-i-1] * P;
            P = P * ALPHABET_SIZE;
        }
        return idx;
    }

    void count(char *s, int len)
    {
        int prefix;
        int suffix;

        for (int i = 0; i < len; i++)
        {
            suffix = s[i+order]; 
            prefix = word2index(&s[i], order);

            T[prefix][suffix] += 1;
            S[prefix] += 1;
        }
    }

    double logP(char *word, int len)
    {
        if (order == 0)
        {
            p = 0.0;
            for (int i = 0; i < len; i++)
                //p += log(priori[(int) word[i]]);
                p += logpriori[(int) word[i]];
        }
        else
        {
            prefix = word2index(word, order);
            p = log(S[prefix]);
            for (int i = order; i < len; i++)
            {
                suffix = (int) word[i]; 
                prefix = word2index(&word[i-order], order);
                p += log(T[prefix][suffix]);
            }
        }
        return p;
    }

    // double P(char *word, int len)
    // {
    //     if (order == 0)
    //     {
    //         p = 1.0;
    //         for (int i = 0; i < len; i++)
    //             p *= priori[(int) word[i]];
    //     }
    //     else
    //     {
    //         prefix = word2index(word, order);
    //         p = S[prefix];
    //         for (int i = order; i < len; i++)
    //         {
    //             suffix = (int) word[i]; 
    //             prefix = word2index(&word[i-order], order);
    //             p *= T[prefix][suffix];
    //         }
    //     }
    //     return p;
    // }

};

// load the model from file in MotifSampler format
// http://homes.esat.kuleuven.be/~thijs/help/help_motifsampler.html
int load_inclusive(Markov &m, string filename);

// construct a Bernoulli model from priori probs (P(A), P(C), P(G), P(T))
int bernoulli(Markov &m, double *priori);

#endif

#include <iostream>
#include <sstream>
#include <cmath>

#include "utils.h"
#include "markov.h"

struct Array 
{
    double **data;
    int I;
    int J;
    double p;
    double pseudo;
    
    Array(int dim1=0, int dim2=0, double val=0.0)
    {
        I = dim1;
        J = dim2;
        data = NULL;
        pseudo = 1.0;
        if (I > 0 && J > 0)
            alloc(I, J, val);
    }

    void alloc(int dim1, int dim2, double val=0.0)
    {
        I = dim1;
        J = dim2;
        if (I <= 0 || J <= 0)
            return;

        // alloc
        data = new double*[I];
        for (int i = 0; i < I; i++)
            data[i] = new double[J];
        
        // init
        for (int i = 0; i < I; i++){
            for (int j = 0; j < J; j++)
                data[i][j] = val;
        }
    }

    Array(const Array& a)
    {
        I = a.I;
        J = a.J;
        alloc(I, J);
        for (int i = 0; i < I; i++)
        {
            for (int j = 0; j < J; j++)
                data[i][j] = a.data[i][j];
        }
    }

    ~Array()
    {
        if (data != NULL)
        {
            for (int i = 0; i < I; i++)
                delete []data[i];
            delete []data;
        }
    }

    Array& operator=(Array &a)
    {
        I = a.I;
        J = a.J;
        alloc(I, J);
        for (int i = 0; i < I; i++)
        {
            for (int j = 0; j < J; j++)
                data[i][j] = a.data[i][j];
        }
        return a;
    }

    double *operator[](int i)
    {
        return data[i];
    }

    double **get_data()
    {
        return data;
    }
    
    string str()
    {
        stringstream buf;
        for (int i = 0; i < I; i++)
        {
            for (int j = 0; j < J; j++)
                buf << data[i][j] << " ";
            buf << endl;
        }
        return buf.str();
    }

    void transform2logfreq(Markov &markov)
    {
        for (int j = 0; j < J; j++)
        {
            double N = 0;
            for (int i = 0; i < I; i++)
                N += data[i][j];
        
            for (int i = 0; i < I; i++)
                data[i][j] = log((data[i][j] + markov.priori[i] * pseudo) / (N + pseudo));
        }
    }

    // Array reverse_complement()
    // {
    //     Array rc = Array(I, J, 0.0);
    // 
    //     int j;
    //     for (j = 0; j < J; j++)
    //     {
    //         int i;
    //         for (i = 0; i < I; i++)
    //         {
    //             int rci;
    //             if (i == 0)
    //                 rci = 3;
    //             else if (i == 1)
    //                 rci = 2;
    //             else if (i == 2)
    //                 rci = 1;
    //             else if (i == 3)
    //                 rci = 0;
    //             rc[rci][J - j - 1] = data[i][j];
    //         }
    //     }
    //     return rc;       
    // }

    double sum(int *word)
    {
        double s = 0.0;
        for (int i = 0; i < J; i++)
            s += data[(int) word[i]][i];
        return s;
    }

    // need to call transform2logfreq before
    double logP(char *word)
    {
        p = 0.0;
        for (int i = 0; i < J; i++)
            p += data[(int) word[i]][i];
        return p;
    }

};

int read_matrix(Array &matrix, char *filename);

#endif
