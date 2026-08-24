/ example schema file: table shapes only, no logic - the kind of file
/ .qt.datagen.forSchema is meant to fill with plausible fixture data.
quote:([] timestamp:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$(); bidSize:`float$(); askSize:`float$(); source:`symbol$());

trade:([] timestamp:`timestamp$(); sym:`symbol$(); price:`float$(); size:`float$(); side:`symbol$(); source:`symbol$());
