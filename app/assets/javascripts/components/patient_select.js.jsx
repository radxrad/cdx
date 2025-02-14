var PatientSelect = React.createClass({
  getInitialState: function() {
    return { patient : this.props.patient };
  },

  getDefaultProps: function() {
    return {
      className: "input-large",
      placeholder: "Search by name or patient id",
      onPatientChanged: null,
      onError: null
    };
  },

  render: function() {
    return (
    <div className="row">
      <div className="col pe-2">
        <label>Patient</label>
      </div>
      <div className="col">

        <label style={{ display: "none" }}>disableautocomplete</label>
        <Select
          value={this.state.patient}
          className="input-xx-large patients"
          placeholder={this.props.placeholder}
          clearable={false}
          asyncOptions={this.search}
          autoload={false}
          onChange={this.onPatientChanged}
          optionRenderer={this.renderOption}
          valueRenderer={this.renderValue}
          valueKey='id'
          cacheAsyncResults={false}
          filterOptions={this.filterOptions}>
        </Select>

        {(function(){
          if (this.state.patient == null) {
            return <a className="btn-add-link" href={"/patients/new?" + $.param({next_url: window.location.href})} title="Create new patient"><span className="icon-circle-plus icon-blue"></span></a>;
          }
        }.bind(this))()}

        <br/>
        <br/>

        {(function(){
          if (this.state.patient != null) {
            return <PatientCard patient={this.state.patient} canEdit={true} />;
          }
        }.bind(this))()}

      </div>
    </div>);
  },

  // private

  onPatientChanged: function(newValue, selection) {
    var patient = (selection && selection[0]) ? selection[0] : null;
    this.setState(
      function(state) {
        return React.addons.update(state, {
          patient: { $set : patient }
        })
      }
      , function() {
        if (this.props.onPatientChanged) {
          this.props.onPatientChanged(patient);
        }
      }.bind(this));
    },

  search: function(value, callback) {
    // FIXME: Search is called when selecting the patient and `value` is no
    //        longer the string to autocomplete but the actual selected patient
    //        object.
    //
    //        We should probably fix what's causing this behavior, but in the
    //        meantime let's just avoid making a bad request!
    if (typeof(value) !== "string") return;

    $.ajax({
      url: '/patients/search',
      data: { context: this.props.context.uuid, q: value },
      success: function(patients) {
        callback(null, {options: patients, complete: false});
        if (patients.length == 0 && this.props.onError) {
          this.props.onError("No patient could be found");
        }
      }.bind(this)
    });
  },

  renderOption: function(option) {
    return (<span key={option.id}>
      {option.name} ({option.age || "n/a"}) {option.entity_id}
    </span>);
  },

  renderValue: function(option) {
    return option.name;
  },

  filterOptions: function(options, filterValue, exclude) {
    return options || [];
  },
});
