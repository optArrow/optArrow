function cfg = getOptArrowConfig()
% getOptArrowConfig Get the active OptArrow MATLAB adapter configuration.
%
% NOTE:
%    'optarrow.getOptArrowConfig()' is MATLAB package namespace syntax from
%    the '+optarrow' folder, not object-oriented method dispatch.
%
% USAGE:
%
%    cfg = optarrow.getOptArrowConfig()
%    import optarrow.*
%    cfg = getOptArrowConfig()
%
% OUTPUT:
%    cfg:          struct, current global configuration for the adapter.
%                  If no configuration exists yet, defaults are initialized
%                  via optarrow.setOptArrowConfig(struct()).
%
% EXAMPLE:
%    cfg = optarrow.getOptArrowConfig();
%    disp(cfg.endpoint);

global OPTARROW_CONFIG

if isempty(OPTARROW_CONFIG)
    cfg = optarrow.setOptArrowConfig(struct());
    return;
end

cfg = OPTARROW_CONFIG;
end
