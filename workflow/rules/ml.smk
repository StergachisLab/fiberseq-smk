localrules:
    make_ml_data,


rule make_ml_data:
    input:
        bam=rules.merge.output.bam,
    output:
        npz="results/{sm}/ml/{sm}.npz",
    conda:
        "m6a_cpu"
    log:
        "logs/{sm}/make_ml_data/ml.log",
    benchmark:
        "benchmarks/{sm}/make_ml_data/ml.tbl"
    threads: 4
    priority: 100
    shell:
        """
        m6adata \
            --train \
            --hifi {input.bam} - \
            -o {output.npz} \
            -s 0.05
        """


rule ml:
    input:
        expand(rules.make_ml_data.output, sm=samples),
