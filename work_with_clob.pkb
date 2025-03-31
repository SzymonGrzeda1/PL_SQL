create or replace package body apex_mail_pkg
as

    gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';

    /**
    * Add an email to the mail queue
    * If the parameter pi_debug_mode is set to Y
    * then the mail to address will be replaced by value in parameter pi_debug_recipients
    *
    * @created 28/08/2024
    *
    * @param   pi_template_static_id    Static identifier string, used to identify the shared component email template.
    * @param   pi_placeholders          JSON string representing the placeholder names along with the values, to be substituted.
    * @param   pi_to                    Mail to address
    * @param   pi_from                  Mail from address
    * @param   pi_cc                    Mail CC address
    * @param   pi_bcc                   Mail BCC address
    * @param   pi_replyto               Reply to address
    * @param   pi_application_id        Application ID where the email template is defined.
    * @param   pi_debug_mode            Debug mode (Y/N)
    * @param   pi_debug_recipients      Mail to addresses in debug mode 
    * @return  APEX Mail ID
    */
    function send(
        pi_template_static_id   in  varchar2,
        pi_placeholders         in  clob,
        pi_to                   in  varchar2,
        pi_from                 in  varchar2,
        pi_cc                   in  varchar2 default null,
        pi_bcc                  in  varchar2 default null,
        pi_replyto              in  varchar2 default null,
        pi_application_id       in  number   default coalesce(v('APP_ID'), 164),
        pi_debug_mode           in  varchar2 default coalesce(v('DEBUG_MODE'), 'N'),
        pi_debug_recipients     in  varchar2 default v('DEBUG_MAIL') 
    ) return number
    is
        l_scope             logger_logs.scope%type := gc_scope_prefix || 'send';
        l_params            logger.tab_param;
        v_apex_mail_id      number;                                     -- APEX Mail ID
        v_to                varchar2(4000);                             -- Mail to address
        v_cc                varchar2(4000);                             -- Mail CC address
        v_bcc               varchar2(4000);                             -- Mail BCC adress
        v_subj              varchar2(4000);                             -- Email subject
        v_body              clob;                                       -- Body text
        v_body_html         clob;                                       -- Body HTML
        v_body_templ        clob;                                       
        v_body_html_templ   clob;
        v_prefix            varchar2(4000);
        v_prefix_html       varchar2(4000);
    begin
        logger.append_param(l_params, 'pi_template_static_id'   , pi_template_static_id);
        --logger.append_param(l_params, 'pi_placeholders'         , pi_placeholders);
        logger.append_param(l_params, 'pi_to'                   , pi_to);
        logger.append_param(l_params, 'pi_from'                 , pi_from);
        logger.append_param(l_params, 'pi_cc'                   , pi_cc);
        logger.append_param(l_params, 'pi_bcc'                  , pi_bcc);
        logger.append_param(l_params, 'pi_replyto'              , pi_replyto);
        logger.append_param(l_params, 'pi_application_id'       , pi_application_id);
        logger.append_param(l_params, 'pi_debug_mode'           , pi_debug_mode);
        logger.append_param(l_params, 'pi_debug_recipients'     , pi_debug_recipients);
        logger.log('START', l_scope, null, l_params);

        dbms_lob.createTemporary( v_body, true );
        dbms_lob.createTemporary( v_body_html, true );
        dbms_lob.createTemporary( v_body_templ, true );
        dbms_lob.createTemporary( v_body_html_templ, true );

        apex_mail.prepare_template (
                    p_static_id         => pi_template_static_id,
                    p_placeholders      => pi_placeholders,
                    p_application_id    => pi_application_id,
                    p_subject           => v_subj,
                    p_text              => v_body_templ,
                    p_html              => v_body_html_templ
            ); 

        -- If parameter pi_debug_mode is Y then we mail to the email address in the pi_debug_recipients parameter
        if pi_debug_mode = 'Y' then
            logger.log('Redirecting email message', l_scope, null, l_params);

            --Indicate that this is a test email
            v_to            := pi_debug_recipients;  
            v_cc            := null;
            v_bcc           := null;                     
            v_subj          := '[TEST] ' || v_subj;
            v_prefix        := 'Original destination:' || chr(10) || 'To: ' || pi_to || chr(10) || 'Cc: ' || pi_cc || chr(10) ||
                                'Bcc: ' || pi_bcc || chr(10);
            v_prefix_html   := '<table><tbody>' ||
                                '<tr><th rowspan="1" colspan="1"><p><strong>Redirected mail. This section will not be displayed in a non-redirected mail.' ||
                                '</strong></p></th><th rowspan="1" colspan="1"><p><strong>Original values</strong></p></th></tr>' ||
                                '<tr><td rowspan="1" colspan="1"><p>To</p></td><td rowspan="1" colspan="1"><p>' || pi_to || '</p></td></tr>' ||
                                '<tr><td rowspan="1" colspan="1"><p>Cc</p></td><td rowspan="1" colspan="1"><p>' || pi_cc || '</p></td></tr>' ||
                                '<tr><td rowspan="1" colspan="1"><p>Bcc</p></td><td rowspan="1" colspan="1"><p>' || pi_bcc || '</p></td></tr>' ||
                                '</tbody></table></br></br>';

            dbms_lob.writeappend( v_body, length(v_prefix), v_prefix );
            dbms_lob.writeappend( v_body_html, length(v_prefix_html), v_prefix_html );

        else
            logger.log('Sending original mail', l_scope, null, l_params);

            v_to        := pi_to;
            v_cc        := pi_cc;
            v_bcc       := pi_bcc;

        end if;

        dbms_lob.append( v_body, v_body_templ );
        dbms_lob.append( v_body_html, v_body_html_templ );

        logger.log('v_subj: ' || v_subj, l_scope, null, l_params);    

        v_apex_mail_id := apex_mail.send(
                            p_to                => v_to,
                            p_from              => pi_from,
                            p_body              => v_body,
                            p_body_html         => v_body_html,
                            p_subj              => v_subj,
                            p_cc                => v_cc,
                            p_bcc               => v_bcc,
                            p_replyto           => pi_replyto
                        );

        dbms_lob.freeTemporary( v_body );
        dbms_lob.freeTemporary( v_body_html );
        dbms_lob.freeTemporary( v_body_templ );
        dbms_lob.freeTemporary( v_body_html_templ );

        logger.log_info('Mail sent with id = "' || v_apex_mail_id || '""', l_scope, null, l_params);

        logger.log('END', l_scope);
        return v_apex_mail_id;
    exception
        when others then
            logger.log_error('Unknown error: ' || SQLERRM, l_scope, null, l_params);
            raise;
    end send;
end apex_mail_pkg;
