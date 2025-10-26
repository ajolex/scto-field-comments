# sctocomments

Stata user-written command to collate SurveyCTO "comments" CSV exports (files like `Comments-<uuid>.csv`) into a single Stata dataset.

## Installation (from GitHub)

```stata
net install sctocomments, from(https://raw.githubusercontent.com/ajolex/scto-field-comments/master/sctocomments) replace
help sctocomments
```

## Usage Examples

Basic usage:
```stata
sctocomments, path("C:/Users/you/yourproject")
```

With survey dataset for merging:
```stata
sctocomments, path("C:/Users/you/yourproject") survey("C:/path/to/survey_data.dta")
```

With main survey dataset for variable values/labels:
```stata
sctocomments, path("C:/Users/you/yourproject") use("C:/path/to/main_survey.dta")
```

## Options

- `path(string)`: Base project folder containing `media` folder (required)
- `filesub(string)`: Filename pattern for comment CSVs (default: "Comments*.csv")  
- `out(string)`: Output filename (default: "comments.dta")
- `survey(string)`: Full path to survey dataset to merge with (optional)
- `use(string)`: Full path to main survey dataset for extracting variable values/labels

## File Structure Expected

```
your_project_folder/
├── media/
│   ├── Comments-uuid1.csv
│   ├── Comments-uuid2.csv
│   └── ...
└── comments.dta (output file)
```

The command processes all CSV files matching the pattern in the media folder and creates a combined dataset with variables: `caseid`, `fo_id`, `fc_id`, `variable`, `comment`, `value`, `label_val`.
