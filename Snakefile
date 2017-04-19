import yaml
configfile: "config.yml"

SAMPLES = yaml.load(open("rawdata/samples.yml"))

rule all:
    input:
        expand("data/reads/{sample}.fastq.gz", sample=SAMPLES),
        expand("data/alignments/ngm/{ref}/{sample}.bam", ref=config["mapping"]["ref"],
               sample=SAMPLES),
        expand("data/alignments/ngm/{ref}_merged.bam", ref=config["mapping"]["ref"]),

rule qcreads:
    input:
        r1=lambda wc: SAMPLES[wc.sample]["R1"],
        r2=lambda wc: SAMPLES[wc.sample]["R2"],
    output:
        reads="data/reads/{sample}.fastq.gz",
        settings="data/log/adapterremoval/{sample}_settings.txt",
    log:
        "data/log/adapterremoval/{sample}.log",
    threads:
        2
    shell:
        "AdapterRemoval"
        "   --file1 <(cat {input.r1})"
        "   --file2 <(cat {input.r2})"
        "   --combined-output"
        "   --interleaved-output"
        "   --collapse"
        "   --trimns"
        "   --trimqualities"
        "   --threads {threads}"
        "   --settings {output.settings}"
        "   --output1 {output.reads}"
        " >{log} 2>&1"

rule ngmap:
    input:
        reads="data/reads/{sample}.fastq.gz",
        ref=lambda wc: config['refs'][wc.ref]
    output:
        bam="data/alignments/ngm/{ref}/{sample}.bam",
        bai="data/alignments/ngm/{ref}/{sample}.bam.bai",
    log:
        "data/log/ngm/{ref}_{sample}.log"
    threads:
        16
    shell:
        "( ngm"
        "   -q {input.reads}"
        "   -p" # paired input
        "   -r {input.ref}"
        "   -t {threads}"
        "   --rg-id {wildcards.sample}"
        "   --rg-sm {wildcards.sample}"
        "   --very-sensitive"
        " | samtools view -Suh -"
        " | samtools sort"
        "   -T ${{TMPDIR:-/tmp}}/{wildcards.sample}"
        "   -@ {threads}"
        "   -m 1G"
        "   -o {output.bam}"
        "   -" # stdin
        " && samtools index {output.bam}"
        " ) >{log} 2>&1"

rule mergebam:
    input:
        expand("data/alignments/ngm/{{ref}}/{sample}.bam", sample=SAMPLES),
    output:
        bam="data/alignments/ngm/{ref}_merged.bam",
        bai="data/alignments/ngm/{ref}_merged.bam.bai",
    log:
        "data/logs/mergebam/{ref}.log"
    threads: 16
    shell:
        "( samtools merge"
        "   -@ {threads}"
        "   {output.bam}"
        "   {input}"
        " && samtools index {output.bam}"
        " ) >{log} 2>&1"
