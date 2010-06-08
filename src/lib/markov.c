#include "markov.h"

markov_t *new_markov(int order)
{
    markov_t *self = malloc(sizeof(markov_t));
    self->order = order;
    int size = pow(4, order);
    self->S = malloc(sizeof(double) * size);
    self->T = malloc(sizeof(double) * (size * 4));
    int i;
    for (i = 0; i < size; i++)
        self->S[i] = 1e-100;
    for (i = 0; i < size * 4; i++)
        self->T[i] = 1e-100;
    return self;
}

void free_markov(markov_t *self)
{
    free(self->S);
    free(self->T);
    free(self);
}

static inline
int char2int(char c)
{
    switch (c)
    {
    case 'a':
    case 'A':
        return 0;
    case 'c':
    case 'C':
        return 1;
    case 'g':
    case 'G':
        return 2;
    break;
    case 't':
    case 'T':
        return 3;
    break;
    default:
        return -1;
    }
}

int oligo2index_char(char *seq, int pos, int l)
{
    int value = 0;
    int S = 1;
    int i;
    for (i = l - 1; i >= 0; i--) 
    {
        int v = char2int(seq[pos + i]);
        if (v == -1)
            return -1;
        value += S * v;
        S *= 4;
    }
    return value;
}

int oligo2index_rc_char(char *seq, int pos, int l)
{
    int value = 0;
    int S = 1;
    int i;
    for (i = 0; i < l; i++) 
    {
        int v = char2int(seq[pos + i]);
        if (v == -1)
            return -1;
        value += S * (3 - v);
        S *= 4;
    }
    return value;
}

// int oligo2index(int *seq, int pos, int l)
// {
//     int value = 0;
//     int S = 1;
//     int i;
//     for (i = l - 1; i >= 0; i--)
//     {
//         if (seq[pos + i] == -1)
//             return -1;
//         value += S * seq[pos + i];
//         S *= 4;
//     }
//     return value;
// }

static
void skip_comments(FILE *fp)
{
    while (!feof(fp))
    {
        int mark = getc(fp);
        ungetc(mark, fp);
        if (mark == ';' || mark == '#')
        {
            while (!feof(fp) && mark != '\n')
                mark = getc(fp);
        }
        else
        {
            break;
        }
    }
}

static
void next_line(FILE *fp)
{
    for (;;)
    {
        int mark = getc(fp);
        if (feof(fp) || mark == '\n')
            break;
    }
}

markov_t *load_markov(char *filename)
{
    // open file
    FILE *fp = fopen(filename, "r");
    ENSURE(fp != NULL, "can not open file");
    markov_t *self = NULL;

    // read file
    for (;;)
    {
        skip_comments(fp);
        if (feof(fp))
            break;
        char id[256];
        float freq;
        fscanf(fp, "%s\t%*s\t%f", id, &freq);
        next_line(fp);
        //INFO("%s %.3f", id, freq);
        if (self == NULL)
        {
            int id_length = strlen(id) - 1;
            self = new_markov(id_length);
        }
        int prefix_index = oligo2index_char(id, 0, self->order);
        self->S[prefix_index] += freq;
        //INFO("id=%s %d, %d", id, prefix_index, 4 * prefix_index + char2int(id[self->order]));
        self->T[4 * prefix_index + char2int(id[self->order])] = freq;
    }
    fclose(fp);

    // compute S & T
    int size = pow(4, self->order);
    int i;
    // S
    double sum = 0;
    for (i = 0; i < size; i++)
        sum += self->S[i];
    for (i = 0; i < size; i++)
        self->S[i] = self->S[i] / sum;
    // T
    for (i = 0; i < size * 4; i += 4)
    {
        int j;
        double sum = 0.0;
        for (j = i; j < i + 4; j++)
            sum += self->T[j];
        for (j = i; j < i + 4; j++)
            self->T[j] = self->T[j] / sum;
    }

    //
    return self;
}

void print_markov(markov_t *self)
{
    int size = pow(4, self->order);

    // S
    printf("S\n");
    int i;
    for (i = 0; i < size; i++)
        printf("%.3f\n", self->S[i]);

    // T
    printf("T\n");
    for (i = 0; i < size * 4; i++)
        printf("%.3f\n", self->T[i]);
}

double markov_P(markov_t *self, char *seq, int pos, int length)
{
    int prefix = oligo2index_char(seq, pos, length - 1);
    if (prefix == -1)
        return 0.0;
    double p = self->S[prefix];
    // INFO("p=%.3f", p);
    int i;
    for (i = self->order; i < length; i++)
    {
        int suffix = char2int(seq[i]);
        int prefix = oligo2index_char(seq, i - self->order, self->order);
        if (suffix == -1 || prefix == -1)
            return 0.0;
        p *= self->T[4 * prefix + suffix];
    }
    // INFO("p=%.3f", p);
    return p;
}
